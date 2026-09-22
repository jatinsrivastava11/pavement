# Model credits

**CarDetectorYOLOv3Tiny.mlmodel**: YOLOv3-Tiny (Joseph Redmon, Ali Farhadi), converted to Core ML
by Apple (developer.apple.com/machine-learning/models, "YOLOv3TinyFP16").
License: YOLO License v2, "Darknet is public domain. Do whatever you want with it."
(github.com/pjreddie/darknet/blob/master/LICENSE). Keras conversion: MIT (qqwweee/keras-yolo3).

**CarDetectorYOLOv3.mlmodel**: full YOLOv3 (Int8 quantized), same authors, conversion and license as
above ("YOLOv3Int8LUT" from Apple's model gallery). Used on the whole photo for large cars.

**CarIdentifierPilot.mlmodel**: Pavement's own image classifier (22 car models plus an "other"
category), trained with Apple Create ML on 2,110 photos from Wikimedia Commons, all under free licenses. The photos
aren't included in the app. Every source file and uploader is listed in
`Data/training/pilot_sources.json`.
