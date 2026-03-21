"""
Southpoint Mall Graph Builder - SIMPLE VERSION
Query everything from OSM, then filter aggressively
"""

import requests
import networkx as nx
import json
import math
import matplotlib.pyplot as plt
from dotenv import load_dotenv
import os

load_dotenv()

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
OPENCAGE_KEY = os.getenv('OPENCAGE_API_KEY')


def calculate_distance(lat1, lon1, lat2, lon2):
    """Calculate distance between two GPS points in meters"""
    R = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    return R * c


def get_shops_from_openstreetmap(latitude, longitude, radius=500):
    """
    Ask OpenStreetMap for all shops near a location
    
    Args:
        latitude: GPS latitude
        longitude: GPS longitude
        radius: How far to search (meters)
    
    Returns:
        List of shops like [{'name': 'Apple Store', 'lat': 35.9, ...}, ...]
    """
    print(f"Asking OpenStreetMap for shops within {radius}m...")
    
    # Build the query - THIS IS THE EXACT QUERY THAT WORKED BEFORE
    query = f"""
    [out:json];
    (
      node["shop"](around:{radius},{latitude},{longitude});
      node["amenity"="restaurant"](around:{radius},{latitude},{longitude});
      node["amenity"="cafe"](around:{radius},{latitude},{longitude});
      node["amenity"="fast_food"](around:{radius},{latitude},{longitude});
      node["amenity"="toilets"](around:{radius},{latitude},{longitude});
      way["shop"](around:{radius},{latitude},{longitude});
      way["amenity"="restaurant"](around:{radius},{latitude},{longitude});
    );
    out center;
    """
    
    # Send request
    response = requests.post(OVERPASS_URL, data={'data': query}, timeout=30)
    
    if response.status_code != 200:
        print(f"Error: Got status code {response.status_code}")
        return []
    
    # Parse response
    data = response.json()
    shops = []
    
    # First pass: collect all stores
    all_stores = []
    for element in data.get('elements', []):
        # Get coordinates
        if element['type'] == 'node':
            lat = element['lat']
            lon = element['lon']
        elif element['type'] == 'way' and 'center' in element:
            lat = element['center']['lat']
            lon = element['center']['lon']
        else:
            continue
        
        tags = element.get('tags', {})
        shop_type = tags.get('shop') or tags.get('amenity', 'unknown')
        name = tags.get('name', f"{shop_type.title()} (unnamed)")
        floor = tags.get('level', '0')
        
        all_stores.append({
            'id': element['id'],
            'name': name,
            'type': shop_type,
            'lat': lat,
            'lon': lon,
            'floor': floor,
            'tags': tags
        })
    
    # ANCHOR-BASED FILTERING
    # Department stores are ALWAYS inside the mall
    # Only keep stores that are close to at least one anchor
    
    landmarks = []
    for s in all_stores:
        # Skip obvious outdoor stuff
        if s['type'] in ['parking', 'car_dealership', 'car', 'fuel', 'car_wash']:
            continue
        # Skip unnamed
        if '(unnamed)' in s['name']:
            continue
        # Must have shop or amenity tag
        if s['type'] != 'unknown':
            landmarks.append(s)
    
    if len(landmarks) < 3:
        print(f"Only {len(landmarks)} landmarks found, keeping all")
        shops = landmarks
        print(f"Found {len(shops)} shops")
        return shops
    
    # Find anchor stores (department stores - always inside)
    anchors = [s for s in landmarks if s['type'] == 'department_store']
    
    if len(anchors) == 0:
        # No anchors found - this is NOT a mall (airport, train station, etc.)
        # Use density clustering instead
        print("No department stores found - using density clustering for non-mall venue")
        
        # Count neighbors for each store (within 100m)
        neighbor_counts = []
        for store in landmarks:
            count = 0
            for other in landmarks:
                if store['id'] != other['id']:
                    dist = calculate_distance(store['lat'], store['lon'], other['lat'], other['lon'])
                    if dist <= 100:  # 100m for non-mall venues (tighter than malls)
                        count += 1
            neighbor_counts.append((store, count))
        
        # Find median neighbor count
        counts = [c for _, c in neighbor_counts]
        if len(counts) == 0:
            print("No stores found")
            return []
        
        counts.sort()
        median_neighbors = counts[len(counts)//2]
        
        # Keep stores with at least 30% of median (looser for non-malls)
        min_neighbors = max(1, int(median_neighbors * 0.3))
        
        print(f"Median neighbors: {median_neighbors}, threshold: {min_neighbors}")
        
        # Filter to dense cluster
        for store, count in neighbor_counts:
            if count >= min_neighbors and store['type'] != 'mall':
                shops.append({
                    'id': store['id'],
                    'name': store['name'],
                    'type': store['type'],
                    'lat': store['lat'],
                    'lon': store['lon'],
                    'floor': store['floor']
                })
        
        print(f"Kept {len(shops)} stores in dense cluster")
        return shops
    
    print(f"Found {len(anchors)} anchor stores (department stores)")
    print(f"Anchor stores: {', '.join([a['name'] for a in anchors])}")
    
    # Calculate max distance between any two anchors
    max_anchor_distance = 0
    for i, a1 in enumerate(anchors):
        for a2 in anchors[i+1:]:
            dist = calculate_distance(a1['lat'], a1['lon'], a2['lat'], a2['lon'])
            max_anchor_distance = max(max_anchor_distance, dist)
    
    # Threshold: keep stores within (max_anchor_distance / 2) of ANY anchor
    # This creates a zone around the anchors that captures the mall interior
    if max_anchor_distance > 0:
        proximity_threshold = max_anchor_distance / 2
    else:
        proximity_threshold = 200  # Single anchor fallback
    
    print(f"Anchor spread: {int(max_anchor_distance)}m")
    print(f"Proximity threshold: {int(proximity_threshold)}m from any anchor")
    
    # Keep stores close to at least one anchor
    indoor_stores = []
    for store in landmarks:
        # Check distance to each anchor
        min_distance_to_anchor = float('inf')
        for anchor in anchors:
            dist = calculate_distance(store['lat'], store['lon'], anchor['lat'], anchor['lon'])
            min_distance_to_anchor = min(min_distance_to_anchor, dist)
        
        # Keep if close to at least one anchor
        if min_distance_to_anchor <= proximity_threshold:
            indoor_stores.append(store)
    
    print(f"Kept {len(indoor_stores)} stores near anchors (removed {len(landmarks) - len(indoor_stores)} outliers)")
    
    # Final filter
    for store in indoor_stores:
        if store['type'] != 'mall':
            shops.append({
                'id': store['id'],
                'name': store['name'],
                'type': store['type'],
                'lat': store['lat'],
                'lon': store['lon'],
                'floor': store['floor']
            })
    
    print(f"Found {len(shops)} shops")
    return shops


def build_graph(shops, max_distance_ft=200, min_distance_ft=10):
    """Connect nearby shops on same floor"""
    print("Building graph...")
    
    max_dist_m = max_distance_ft * 0.3048
    min_dist_m = min_distance_ft * 0.3048
    
    graph = nx.Graph()
    
    # Add nodes
    for shop in shops:
        graph.add_node(
            shop['id'],
            name=shop['name'],
            type=shop['type'],
            floor=shop['floor'],
            lat=shop['lat'],
            lon=shop['lon'],
            pos=(shop['lon'], shop['lat'])
        )
    
    # Add edges
    nodes = list(graph.nodes())
    for i, node1 in enumerate(nodes):
        for node2 in nodes[i+1:]:
            # Same floor only
            if graph.nodes[node1]['floor'] != graph.nodes[node2]['floor']:
                continue
            
            # Calculate distance
            lat1 = graph.nodes[node1]['lat']
            lon1 = graph.nodes[node1]['lon']
            lat2 = graph.nodes[node2]['lat']
            lon2 = graph.nodes[node2]['lon']
            
            distance_m = calculate_distance(lat1, lon1, lat2, lon2)
            distance_ft = distance_m / 0.3048
            
            # Connect if in range
            if min_dist_m <= distance_m <= max_dist_m:
                graph.add_edge(node1, node2, weight=distance_ft)
    
    print(f"Graph: {len(graph.nodes)} nodes, {len(graph.edges)} edges")
    return graph


def get_neighbors(graph, store_name, n=3):
    """Find N closest connected stores"""
    target_node = None
    for node_id in graph.nodes():
        if graph.nodes[node_id]['name'].lower() == store_name.lower():
            target_node = node_id
            break
    
    if target_node is None:
        return []
    
    neighbors = []
    for neighbor_id in graph.neighbors(target_node):
        neighbor_name = graph.nodes[neighbor_id]['name']
        distance_ft = graph[target_node][neighbor_id]['weight']
        neighbors.append((neighbor_name, distance_ft))
    
    neighbors.sort(key=lambda x: x[1])
    return neighbors[:n]


def make_vlm_context(graph, current_store, destination=None):
    """Generate context string for VLM"""
    neighbors = get_neighbors(graph, current_store, n=3)
    
    if not neighbors:
        return f"You are near {current_store}."
    
    parts = [f"You are near {current_store}."]
    neighbor_list = [f"{name} ({int(dist)} feet)" for name, dist in neighbors]
    parts.append(f"Nearby: {', '.join(neighbor_list)}.")
    
    if destination:
        matching = []
        for node_id in graph.nodes():
            node_type = graph.nodes[node_id]['type']
            node_name = graph.nodes[node_id]['name']
            if destination.lower() in node_type.lower() or destination.lower() in node_name.lower():
                matching.append(node_name)
        
        if matching:
            parts.append(f"{destination.title()}: {', '.join(matching[:3])}.")
    
    return " ".join(parts)


def save_graph(graph, filename="southpoint_graph.json"):
    """Save to JSON"""
    data = {
        'nodes': [{'id': nid, **graph.nodes[nid]} for nid in graph.nodes()],
        'edges': [{'source': u, 'target': v, **graph[u][v]} for u, v in graph.edges()]
    }
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Saved to {filename}")


def visualize_graph(graph, filename="southpoint_graph.png"):
    """Create visualization"""
    plt.figure(figsize=(16, 12))
    pos = nx.get_node_attributes(graph, 'pos')
    
    nx.draw_networkx_nodes(graph, pos, node_color='lightblue', node_size=500, alpha=0.9)
    nx.draw_networkx_edges(graph, pos, alpha=0.3, width=1)
    
    labels = {node: graph.nodes[node]['name'][:20] for node in graph.nodes()}
    nx.draw_networkx_labels(graph, pos, labels, font_size=8)
    
    plt.title("Indoor Navigation Graph")
    plt.axis('off')
    plt.savefig(filename, dpi=300, bbox_inches='tight')
    print(f"Saved to {filename}")
    plt.close()


def main():
    print("=" * 60)
    print("SOUTHPOINT MALL GRAPH BUILDER")
    print("=" * 60)
    
    # Southpoint Mall coordinates
    lat = 35.9036
    lon = -78.9415
    
    # Get data
    shops = get_shops_from_openstreetmap(lat, lon, radius=500)
    
    # Print all shops
    print("\nAll Shops Found:")
    print("=" * 60)
    for shop in shops:
        print(f"{shop['name']:40} | {shop['type']:20} | Floor: {shop['floor']}")
    
    if not shops:
        print("No shops found!")
        return
    
    # Build graph
    graph = build_graph(shops, max_distance_ft=667, min_distance_ft=10)
    
    # Test navigation
    print("\n" + "=" * 60)
    print("TESTING NAVIGATION")
    print("=" * 60)
    
    if shops:
        test_store = shops[0]['name']
        print(f"\nExample: User sees '{test_store}'")
        
        neighbors = get_neighbors(graph, test_store, n=3)
        if neighbors:
            print("Closest neighbors:")
            for name, dist in neighbors:
                print(f"  - {name}: {int(dist)} feet")
        
        context = make_vlm_context(graph, test_store, "toilets")
        print(f"\nVLM Context: {context}")
    
    # Save
    print("\n" + "=" * 60)
    print("SAVING")
    print("=" * 60)
    save_graph(graph, "southpoint_graph.json")
    visualize_graph(graph, "southpoint_graph.png")
    
    print("\nDONE!")
    print(f"Stores: {len(shops)}")
    print(f"Connections: {len(graph.edges)}")


if __name__ == "__main__":
    main()