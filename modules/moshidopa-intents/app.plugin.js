const { withXcodeProject, withInfoPlist } = require('@expo/config-plugins');

const MIN_IOS_DEPLOYMENT_TARGET = 16.4;

function parseDeploymentTarget(value) {
  const parsed = Number.parseFloat(String(value ?? ''));
  return Number.isFinite(parsed) ? parsed : MIN_IOS_DEPLOYMENT_TARGET;
}

function withMoshidopaIntents(config, props = {}) {
  // ExpoModulesCore and ExpoModulesJSI in SDK 57 require iOS 16.4. Never let
  // an app config or an existing Xcode setting lower that requirement.
  const requestedTarget = parseDeploymentTarget(props.deploymentTarget);
  const minimumTarget = Math.max(MIN_IOS_DEPLOYMENT_TARGET, requestedTarget);

  config = withXcodeProject(config, (projectConfig) => {
    const project = projectConfig.modResults;
    for (const nativeTarget of Object.values(project.pbxNativeTargetSection())) {
      if (nativeTarget.productType === '"com.apple.product-type.application"') {
        const buildSettings = project.pbxXCBuildConfigurationSection();
        Object.values(buildSettings).forEach((settings) => {
          if (settings.buildSettings) {
            const existingTarget = parseDeploymentTarget(settings.buildSettings.IPHONEOS_DEPLOYMENT_TARGET);
            settings.buildSettings.IPHONEOS_DEPLOYMENT_TARGET = String(Math.max(minimumTarget, existingTarget));
          }
        });
      }
    }
    return projectConfig;
  });

  return withInfoPlist(config, (plistConfig) => {
    const urlTypes = plistConfig.modResults.CFBundleURLTypes || [];
    if (!urlTypes.some((entry) => entry.CFBundleURLSchemes?.includes('moshidopa'))) {
      urlTypes.push({CFBundleURLSchemes: ['moshidopa']});
    }
    plistConfig.modResults.CFBundleURLTypes = urlTypes;
    return plistConfig;
  });
}

module.exports = withMoshidopaIntents;
