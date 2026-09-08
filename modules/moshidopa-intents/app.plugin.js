const { withXcodeProject, withInfoPlist } = require('@expo/config-plugins');

function withMoshidopaIntents(config, props = {}) {
  const deploymentTarget = props.deploymentTarget || '16.0';

  config = withXcodeProject(config, (projectConfig) => {
    const project = projectConfig.modResults;
    for (const nativeTarget of Object.values(project.pbxNativeTargetSection())) {
      if (nativeTarget.productType === '"com.apple.product-type.application"') {
        const buildSettings = project.pbxXCBuildConfigurationSection();
        Object.values(buildSettings).forEach((settings) => {
          if (settings.buildSettings) {
            settings.buildSettings.IPHONEOS_DEPLOYMENT_TARGET = deploymentTarget;
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
