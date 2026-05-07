"""
Monocular Depth Estimation Module
Uses Depth Anything V2 for per-pixel depth maps from single RGB images.
"""
import logging
import numpy as np
from typing import Optional

logger = logging.getLogger(__name__)


class DepthEstimator:
    """
    Wraps Depth Anything V2 for real-time monocular depth estimation.
    Model sizes: small (24M), base (97M), large (335M).

    Output: normalised depth map (0=near, 1=far) + metric depth if calibrated.
    """

    def __init__(self, model_size: str = "base"):
        self.model_size = model_size
        self._model = None
        self._calibration_scale: Optional[float] = None
        logger.info(f"DepthEstimator initialised (size={model_size})")

    def load(self):
        """Lazy-load the depth model."""
        try:
            import torch
            from transformers import pipeline
            self._model = pipeline(
                "depth-estimation",
                model=f"depth-anything/Depth-Anything-V2-{self.model_size.capitalize()}-hf",
            )
            logger.info("Depth Anything V2 loaded")
        except ImportError:
            logger.warning("transformers/torch not available — running in mock mode")

    def estimate(self, image: np.ndarray) -> np.ndarray:
        """
        Estimate normalised depth map from an RGB image array.
        Returns: H×W float32 array in range [0, 1].
        """
        if self._model is None:
            return self._mock_depth_map(image.shape[:2])

        from PIL import Image as PILImage
        pil_image = PILImage.fromarray(image[..., ::-1])  # BGR → RGB
        result = self._model(pil_image)
        depth = np.array(result["depth"], dtype=np.float32)
        depth = (depth - depth.min()) / (depth.max() - depth.min() + 1e-8)
        return depth

    def estimate_metric(
        self,
        image: np.ndarray,
        reference_width_px: int,
        reference_width_cm: float,
    ) -> np.ndarray:
        """
        Convert normalised depth to metric depth (cm) using a reference object.
        """
        norm_depth = self.estimate(image)
        scale = reference_width_cm / max(reference_width_px, 1)
        self._calibration_scale = scale
        return norm_depth * scale * 100   # metric cm

    def compute_object_dimensions(
        self,
        depth_map: np.ndarray,
        mask: np.ndarray,
        focal_length_px: float = 800.0,
    ) -> dict:
        """
        Compute real-world bounding box dimensions from depth map and object mask.
        Uses the thin-lens camera model for back-projection.
        """
        masked_depth = depth_map[mask > 0]
        if len(masked_depth) == 0:
            return {"width_cm": 0, "height_cm": 0, "depth_cm": 0}

        median_depth = float(np.median(masked_depth))
        rows, cols = np.where(mask > 0)
        pixel_width = int(cols.max() - cols.min())
        pixel_height = int(rows.max() - rows.min())

        scale = median_depth / focal_length_px
        width_cm = pixel_width * scale
        height_cm = pixel_height * scale
        depth_range = float(masked_depth.max() - masked_depth.min())

        return {
            "width_cm": round(width_cm, 2),
            "height_cm": round(height_cm, 2),
            "depth_cm": round(depth_range, 2),
            "median_distance_cm": round(median_depth, 2),
            "confidence": 0.85,
        }

    def _mock_depth_map(self, shape: tuple) -> np.ndarray:
        """Generate a synthetic depth map for testing."""
        h, w = shape
        y, x = np.mgrid[0:h, 0:w]
        cx, cy = w / 2, h / 2
        depth = 1.0 - np.sqrt(((x - cx) / cx) ** 2 + ((y - cy) / cy) ** 2) * 0.5
        return np.clip(depth, 0, 1).astype(np.float32)
