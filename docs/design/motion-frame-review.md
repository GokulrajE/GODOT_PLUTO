# Motion and frame pacing review

Hat Trick now uses a fixed 80x80 falling ball; the legacy bomb-size branch is removed. Hat Trick and Fruit Catch reuse their falling sprite nodes. RNR uses a bounded pool of drops, emitting every 55ms from the cloud with staggered horizontal positions and downward speeds. The cloud SVG now has layered highlights and blue underside shading.

The project defaults to Compatibility rendering for its 2D scenes. Tuk Tuk preloads its panorama shader instead of constructing shader source on scene entry; scrolling remains delta-based and respects pause/reduced motion.

Validation: 242 gameplay checks passed across all five games. A separate rendered run passed 283 checks, including fixed ball dimensions and staggered rain. Sampled 180 warmed frames per game at 1280x800 with a 60 FPS cap on Intel UHD graphics: medians 16.61–16.76ms, p95 17.75–18.29ms, maximum 22.83ms. None of the 900 sampled frames exceeded 25ms. This short local sample does not guarantee elimination of all intermittent or hardware-dependent stutters. The motion runner emitted a resource-cleanup warning at shutdown.
