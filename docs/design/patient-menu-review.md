# Patient menu refresh and HOC assessment display

Updated 2026-10-14. Shared saved-scene artwork provides warm garden scenery, raised cards, and navy action icons across the 11 menu/setup scenes. Ambient margin highlights respect Reduced motion. Menu music is joaquinton's CC0 relax_background1; Back and Confirm use distinct Kenney CC0 cues. Icons use Lucide (ISC); licenses and sources are bundled under Assets/Arcade/Online.

HOC previously normalized against a symmetric negative-to-positive scale despite its negative-to-zero calibrated motion. A shared display function now maps -calib_angle through zero over the entire track for current, min/max, and historical cycle markers in AROM and PROM. Non-HOC remains symmetric. Invalid values are guarded, the incorrect central Closed label is hidden, and live HOC values use centimetres. Sensor logging, assessment algorithms and motor commands are unchanged.

Validation: 19 HOC display checks, 47 UI interaction checks, and 17 saved-scene render checks pass. Visually reviewed login, plan setup and assessment views. HOC checks use synthetic angles; physical device calibration and range require verification with connected hardware. Original patient records were not modified by this work.
