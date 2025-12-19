// AI Vision Bridge for Flutter
// Uses TensorFlow.js MoveNet to detect poses

let detector;

async function loadModel() {
  console.log("Loading MoveNet model...");
  const detectorConfig = {
    modelType: poseDetection.movenet.modelType.SINGLEPOSE_THUNDER // Changed from LIGHTNING to THUNDER for higher accuracy
  };
  detector = await poseDetection.createDetector(
    poseDetection.SupportedModels.MoveNet, 
    detectorConfig
  );
  console.log("MoveNet model loaded!");
  return "loaded";
}

async function analyzeImage(imageElementId) {
  if (!detector) {
    await loadModel();
  }

  const img = document.getElementById(imageElementId);
  if (!img) {
    console.error("Image element not found: " + imageElementId);
    return null;
  }

  try {
    // DO NOT resize explicitly here if possible, let TFJS handle it.
    // MoveNet expects square inputs but the library handles preprocessing.
    const poses = await detector.estimatePoses(img, {
        maxPoses: 1,
        flipHorizontal: false
    });

    if (poses.length > 0) {
      const pose = poses[0];
      
      // Get the ACTUAL dimensions of the image being displayed/processed
      // This is critical. TFJS returns coordinates relative to THIS element's dimensions.
      const width = img.width; 
      const height = img.height;
      
      // Normalize coordinates to 0.0 - 1.0 range
      pose.keypoints.forEach(kp => {
        kp.x = kp.x / width;
        kp.y = kp.y / height;
      });
      
      return JSON.stringify(pose);
    }
    return null;
  } catch (e) {
    console.error("Pose detection failed:", e);
    return null;
  }
}

window.loadAiModel = loadModel;
window.runAiAnalysis = analyzeImage;
