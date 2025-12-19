// AI Vision Bridge for Flutter
// Uses TensorFlow.js MoveNet to detect poses

let detector;

async function loadModel() {
  console.log("Loading MoveNet model...");
  const detectorConfig = {
    modelType: poseDetection.movenet.modelType.SINGLEPOSE_LIGHTNING
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
    const poses = await detector.estimatePoses(img);
    if (poses.length > 0) {
      const pose = poses[0];
      // Normalize coordinates
      const width = img.naturalWidth || img.width;
      const height = img.naturalHeight || img.height;
      
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
