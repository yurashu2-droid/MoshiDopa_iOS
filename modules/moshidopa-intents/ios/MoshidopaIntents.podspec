require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'MoshidopaIntents'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = { :type => 'MIT' }
  s.author         = { 'Moshidopa' => 'yurashu2@gmail.com' }
  s.platforms      = { :ios => '16.4' }
  # The module is linked from the app's local path by Expo autolinking.
  s.source         = { git: '' }
  s.static_framework = true
  s.swift_version  = '6.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.source_files   = '**/*.{h,m,mm,swift}'
  s.dependency     'ExpoModulesCore'
end
