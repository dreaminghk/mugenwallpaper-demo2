# MuGen Wallpaper Cloud

This is a simple library to render volumetric clouds on a web page. It uses WebGL and shaders to create a dynamic and physically-inspired cloudscape.

## Usage

1.  Include the `mugenwallpaper.cloud.js` script in your HTML file.
2.  Create a `<canvas>` element with an ID (default is `clouds`).
3.  Call the `cloud()` function with an optional configuration object.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Cloud Demo</title>
</head>
<body>
  <canvas id="clouds"></canvas>

  <script src="mugenwallpaper.cloud.js"></script>
  <script>
    cloud({
      // Optional configuration
    });
  </script>
</body>
</html>
```

## Configuration

The `cloud()` function takes an optional configuration object with the following properties:

| Name              | Type      | Default       | Description                                                 |
| ----------------- | --------- | ------------- | ----------------------------------------------------------- |
| `canvasId`        | `string`  | `"clouds"`      | The ID of the canvas element to use.                        |
| `targetDPR`       | `number`  | `1.0`         | The target device pixel ratio.                              |
| `renderScale`     | `number`  | `0.66`        | The rendering scale.                                        |
| `coverage`        | `number`  | `0.55`        | Higher value means fewer/thinner clouds.                    |
| `density`         | `number`  | `0.9`         | Lower opacity overall.                                      |
| `thickness`       | `number`  | `1.2`         | Kept for volumetric path.                                   |
| `scale`           | `number`  | `0.3`         | The spatial scale of the clouds.                            |
| `lightAbsorption` | `number`  | `1.5`         | Volumetric path only.                                       |
| `windSpeed`       | `number`  | `0.006`       | The speed of the wind.                                      |
| `windDir`         | `array`   | `[0.7, 0.2]`  | The direction of the wind.                                  |
| `sunColor`        | `array`   | `[1.0, 0.97, 0.92]` | The color of the sun.                                     |
| `targetFPS`       | `number`  | `0`           | The target frames per second (0 for unlimited).             |