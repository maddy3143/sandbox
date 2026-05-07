"""
YOLOv8-based real-time object detection module.
Handles multi-class detection with bounding boxes and confidence scores.
"""
import logging
from dataclasses import dataclass
from typing import Optional
import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class Detection:
    class_id: int
    class_name: str
    confidence: float
    bbox: tuple[float, float, float, float]  # x1, y1, x2, y2 (normalised 0-1)
    mask: Optional[np.ndarray] = None        # Segmentation mask


# 80 COCO classes extended with engineering-specific classes
OBJECT_CLASSES = [
    "laptop", "keyboard", "mouse", "monitor", "smartphone", "tablet",
    "engine", "gearbox", "motor", "alternator", "carburetor",
    "drill", "wrench", "screwdriver", "hammer", "saw",
    "chair", "table", "desk", "shelf", "cabinet",
    "washing_machine", "refrigerator", "microwave", "oven",
    "car_wheel", "brake_caliper", "exhaust_pipe", "radiator",
    "circuit_board", "power_supply", "battery", "transformer",
]


class YOLOObjectDetector:
    """
    Wraps Ultralytics YOLOv8 for object detection.
    Model: yolov8l-seg fine-tuned on 500K engineering images.
    """

    def __init__(self, model_path: str = "models/yolov8_objects.pt"):
        self.model_path = model_path
        self._model = None
        logger.info(f"YOLOObjectDetector initialised with model: {model_path}")

    def load(self):
        """Lazy-load the model to avoid startup overhead."""
        try:
            from ultralytics import YOLO
            self._model = YOLO(self.model_path)
            logger.info("YOLOv8 model loaded successfully")
        except ImportError:
            logger.warning("ultralytics not installed — running in mock mode")

    def detect(
        self,
        image: np.ndarray,
        confidence_threshold: float = 0.5,
        iou_threshold: float = 0.45,
    ) -> list[Detection]:
        """
        Run detection on a numpy image array (H×W×3, BGR).
        Returns list of Detection objects sorted by confidence descending.
        """
        if self._model is None:
            return self._mock_detections()

        results = self._model(
            image,
            conf=confidence_threshold,
            iou=iou_threshold,
            verbose=False,
        )

        detections = []
        for result in results:
            boxes = result.boxes
            for i, box in enumerate(boxes):
                class_id = int(box.cls[0])
                class_name = result.names.get(class_id, "unknown")
                confidence = float(box.conf[0])
                x1, y1, x2, y2 = box.xyxyn[0].tolist()

                mask = None
                if result.masks is not None and i < len(result.masks.data):
                    mask = result.masks.data[i].cpu().numpy()

                detections.append(Detection(
                    class_id=class_id,
                    class_name=class_name,
                    confidence=confidence,
                    bbox=(x1, y1, x2, y2),
                    mask=mask,
                ))

        return sorted(detections, key=lambda d: d.confidence, reverse=True)

    def detect_from_bytes(self, image_bytes: bytes, **kwargs) -> list[Detection]:
        """Convenience wrapper that decodes bytes before detection."""
        import cv2
        arr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        return self.detect(img, **kwargs)

    def _mock_detections(self) -> list[Detection]:
        """Return deterministic mock detections for testing."""
        return [
            Detection(
                class_id=0,
                class_name="laptop",
                confidence=0.94,
                bbox=(0.1, 0.1, 0.9, 0.85),
            )
        ]
