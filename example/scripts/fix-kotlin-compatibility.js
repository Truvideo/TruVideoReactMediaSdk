#!/usr/bin/env node

/**
 * Post-install script to fix React Native Gradle plugin compatibility with Kotlin 2.2.0
 * This script updates the React Native Gradle plugin to use Kotlin 2.2.0
 */

const fs = require('fs');
const path = require('path');

const gradlePluginPath = path.join(__dirname, '../node_modules/@react-native/gradle-plugin');
const versionCatalogPath = path.join(gradlePluginPath, 'gradle/libs.versions.toml');
const buildGradlePath = path.join(gradlePluginPath, 'build.gradle.kts');

function updateVersionCatalog() {
  if (!fs.existsSync(versionCatalogPath)) {
    console.log('Version catalog not found, skipping...');
    return;
  }

  let content = fs.readFileSync(versionCatalogPath, 'utf8');
  if (content.includes('kotlin = "1.9.22"')) {
    content = content.replace('kotlin = "1.9.22"', 'kotlin = "2.2.0"');
    fs.writeFileSync(versionCatalogPath, content, 'utf8');
    console.log('✓ Updated Kotlin version in version catalog to 2.2.0');
  }
}

function updateBuildGradle() {
  if (!fs.existsSync(buildGradlePath)) {
    console.log('build.gradle.kts not found, skipping...');
    return;
  }

  let content = fs.readFileSync(buildGradlePath, 'utf8');
  let updated = false;

  // Update kotlinOptions to compilerOptions
  if (content.includes('kotlinOptions {')) {
    content = content.replace(
      /tasks\.withType<KotlinCompile>\(\)\.configureEach \{[^}]*kotlinOptions \{[^}]*\}[^}]*\}/s,
      `tasks.withType<KotlinCompile>().configureEach {
  compilerOptions {
    // See comment above on JDK 11 support
    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    allWarningsAsErrors.set(false) // Disabled to allow Kotlin 2.2.0 compatibility
  }
}`
    );
    updated = true;
  }

  if (updated) {
    fs.writeFileSync(buildGradlePath, content, 'utf8');
    console.log('✓ Updated build.gradle.kts for Kotlin 2.2.0 compatibility');
  }
}

// Run updates
try {
  updateVersionCatalog();
  updateBuildGradle();
  console.log('✓ Kotlin 2.2.0 compatibility fixes applied successfully');
} catch (error) {
  console.error('Error applying Kotlin compatibility fixes:', error);
  process.exit(1);
}
