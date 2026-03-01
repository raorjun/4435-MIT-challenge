# System Architecture

## Overview

Indoor Navigation Assistant uses a **hybrid localization** approach combining:

1. **VIO** (Visual-Inertial Odometry) - ARKit/ARCore for drift-free tracking
2. **WiFi** Fingerprinting - Periodic position corrections
3. **Map Database** - Pre-loaded floor plans for pathfinding
4. **VLM Fallback** - Gemini 2.5 Flash-Lite when uncertain

## High-Level Architecture

```
┌─────────────────────────────────────────────────┐
│          Mobile App (Flutter)                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌────────────────────────────────────────┐    │
│  │      Localization Layer                │    │
│  │  ┌──────────┐ ┌──────────┐ ┌────────┐ │    │
│  │  │   VIO    │ │   WiFi   │ │  Step  │ │    │
│  │  │ Tracker  │ │ Locator  │ │Counter │ │    │
│  │  └──────────┘ └──────────┘ └────────┘ │    │
│  │         │           │           │      │    │
│  │         └───────────┴───────────┘      │    │
│  │                  │                     │    │
│  │           Hybrid Fusion                │    │
│  └────────────────────────────────────────┘    │
│                    │                           │
│  ┌────────────────────────────────────────┐    │
│  │      Navigation Layer                  │    │
│  │  ┌──────────┐ ┌──────────┐ ┌────────┐ │    │
│  │  │   Map    │ │    A*    │ │ Gemini │ │    │
│  │  │ Database │ │Pathfinder│ │  VLM   │ │    │
│  │  └──────────┘ └──────────┘ └────────┘ │    │
│  └────────────────────────────────────────┘    │
│                    │                           │
│  ┌────────────────────────────────────────┐    │
│  │      Presentation Layer                │    │
│  │  ┌──────────┐ ┌──────────┐            │    │
│  │  │  Audio   │ │  Visual  │            │    │
│  │  │Feedback  │ │   UI     │            │    │
│  │  └──────────┘ └──────────┘            │    │
│  └────────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
  ┌─────────────┐           ┌──────────────┐
  │ Local       │           │ Gemini API   │
  │ Map DB      │           │ (Cloud)      │
  │ (SQLite)    │           │ Flash-Lite   │
  └─────────────┘           └──────────────┘
```

## Data Flow

### Typical Navigation Session

1. **Initialization**
   - User opens app
   - GPS detects approximate location
   - App identifies venue (e.g., "SouthPark Mall")
   - Load floor plan from local database

2. **Position Initialization**
   - User selects entrance ("North Entrance")
   - VIO (ARKit/ARCore) session starts
   - Initial position set on map

3. **Destination Selection**
   - User speaks: "Take me to the bathroom"
   - App finds bathroom locations on floor plan
   - A* pathfinding calculates route

4. **Navigation Loop** (every 0.5 seconds)
   ```
   a. VIO updates position
   b. Every 10 seconds: WiFi correction
   c. Calculate distance to next waypoint
   d. Generate audio instruction
   e. Speak to user
   f. Check if arrived
   ```

5. **VLM Fallback** (when needed)
   - VIO confidence < 50%
   - User stuck (no progress 30 sec)
   - Approaching destination
   ```
   → Capture camera frame
   → Send to Gemini 2.5 Flash-Lite
   → Receive verbal guidance
   → Speak to user
   ```

## Key Design Decisions

### Why Hybrid Localization?

| Method | Accuracy | Drift | Cost | Works Offline |
|--------|----------|-------|------|---------------|
| GPS | 10-50m | None | Free | Yes |
| VIO only | 0.5-1m | Medium | Free | Yes |
| WiFi only | 3-5m | None | Free | Yes |
| **VIO + WiFi** | **0.3-0.8m** | **Minimal** | **Free** | **Yes** |
| VLM only | Variable | N/A | $$$$ | No |

**Conclusion**: VIO + WiFi gives best accuracy at zero cost, with VLM as intelligent fallback.

### Why Gemini 2.5 Flash-Lite?

- **4× more free requests** than Flash (1,000 vs 250/day)
- **70% cheaper** when scaled ($0.10 vs $0.30 per 1M tokens)
- **Faster** (lower latency)
- **Good enough** for navigation (91% vs 94% accuracy)

See [VLM Comparison Guide](../research/vlm_comparison.md) for full analysis.

## Technology Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| **Mobile** | Flutter | Cross-platform, fast development |
| **AR/VIO** | ARKit (iOS), ARCore (Android) | Industry standard, drift-free |
| **Database** | SQLite | Offline-first, lightweight |
| **VLM** | Gemini 2.5 Flash-Lite | Free tier, fast, cheap |
| **ML** | YOLOv8-nano | Mobile-optimized, accurate |
| **Audio** | Flutter TTS | Native, accessible |

## Performance Targets

- Position accuracy: < 1 meter
- Update rate: 2 Hz (twice per second)
- VLM latency: < 2 seconds
- Battery usage: < 15% per hour
- Works offline: Yes (map-based mode)

## Future Enhancements

- [ ] Store logo detection for better localization
- [ ] Multi-floor navigation
- [ ] Crowdsourced map updates
- [ ] AR visual overlays
- [ ] Offline voice synthesis
