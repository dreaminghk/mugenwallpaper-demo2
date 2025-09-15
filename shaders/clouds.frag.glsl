precision highp float;
varying vec2 v_uv;
uniform float u_time;
uniform vec2 u_resolution;
uniform vec2 u_wind;
uniform vec3 u_sunDir;      // normalized sun direction (from sky to scene)
uniform vec3 u_sunColor;    // sunlight color
uniform float u_coverage;   // base coverage threshold [0..1]
uniform float u_density;    // density scale
uniform float u_thickness;  // cloud layer thickness in arbitrary units
uniform float u_scale;      // spatial frequency scale
uniform float u_lightAbsorption; // how quickly light is absorbed

const bool FAST_MODE = true; // ultra-fast 2D lighting approximation for 120Hz

// Hash helpers
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123); }

// 2D value noise
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  // four corners
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// 3D value noise
float noise3(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  float n000 = hash3(i + vec3(0.0, 0.0, 0.0));
  float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
  float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
  float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
  float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
  float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
  float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
  float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
  vec3 u = f * f * (3.0 - 2.0 * f);
  float nx00 = mix(n000, n100, u.x);
  float nx10 = mix(n010, n110, u.x);
  float nx01 = mix(n001, n101, u.x);
  float nx11 = mix(n011, n111, u.x);
  float nxy0 = mix(nx00, nx10, u.y);
  float nxy1 = mix(nx01, nx11, u.y);
  return mix(nxy0, nxy1, u.z);
}

// Fractal Brownian Motion (2D)
float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = m * p * 1.9;
    a *= 0.5;
  }
  return v;
}

// Fractal Brownian Motion (3D) — reduced octaves for performance
float fbm3(vec3 p) {
  float v = 0.0;
  float a = 0.5;
  mat3 m = mat3( 1.6,  1.2,  0.0,
                 -1.2,  1.6,  0.0,
                  0.0,  0.0,  1.7);
  for (int i = 0; i < 4; i++) {
    v += a * noise3(p);
    p = m * p * 1.8 + 0.1;
    a *= 0.5;
  }
  return v;
}

// Simple curl-like warp from 2D FBM gradients to add turbulence
vec2 domainWarp(vec2 p) {
  float e = 0.06;
  float n1 = fbm(p * 0.9);
  float n2 = fbm((p + vec2(5.2, 1.3)) * 0.9);
  return e * vec2(n2 - n1, n1 - n2);
}

// Henyey-Greenstein phase (simplified)
float hgPhase(float cosTheta, float g) {
  float g2 = g * g;
  float denom = pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
  return (1.0 - g2) / (4.0 * 3.14159265 * denom);
}

// Fast 2D approximation path: single-pass, no raymarch
vec4 fastClouds(vec2 uv, vec2 advect, vec2 aspect) {
  vec2 warped = uv * u_scale + advect + domainWarp(uv * 0.5 + 0.02 * u_time);
  float base = fbm(warped * 1.3);
  float detail = fbm(warped * 2.2 + 13.7);
  float micro = fbm(warped * 4.0 + 31.1);
  float n = mix(base, detail, 0.30);
  n = mix(n, micro, 0.10);
  float d = smoothstep(u_coverage - 0.12, u_coverage + 0.06, n);
  d = pow(d, 1.25) * u_density;
  d = clamp(d, 0.0, 1.0);

  vec2 sd = normalize(vec2(u_sunDir.x, u_sunDir.y) + vec2(1e-5));
  sd *= 0.09;
  float occ = 0.0;
  occ += smoothstep(u_coverage - 0.10, u_coverage + 0.10, fbm((warped + sd) * 1.4));
  occ += smoothstep(u_coverage - 0.10, u_coverage + 0.10, fbm((warped + sd*2.0) * 1.3)) * 0.6;
  occ += smoothstep(u_coverage - 0.10, u_coverage + 0.10, fbm((warped + sd*3.5) * 1.2)) * 0.35;
  float shadow = clamp(1.0 - occ * 0.38, 0.45, 1.0);

  vec3 albedo = vec3(1.16, 1.16, 1.20);
  vec3 light = u_sunColor * (0.65 + 0.35 * shadow);
  vec3 color = albedo * light;
  float alpha = clamp(0.06 + 0.85 * d, 0.0, 1.0);
  return vec4(color, alpha);
}

void main() {
  vec2 aspect = vec2(u_resolution.x / min(u_resolution.x, u_resolution.y),
                     u_resolution.y / min(u_resolution.x, u_resolution.y));
  vec2 uv = (v_uv * 2.0 - 1.0) * aspect;

  float t = u_time;
  vec2 wind = u_wind;
  vec2 advect = wind * t;

  if (FAST_MODE) {
    gl_FragColor = fastClouds(uv, advect, aspect);
    return;
  }

  vec2 warped = uv * u_scale + advect + domainWarp(uv * 0.6 + 0.1 * t);
  float baseMask = fbm(uv * (0.9 * u_scale) + advect * 0.5);
  float cover = smoothstep(u_coverage - 0.08, u_coverage + 0.08, baseMask);

  const int STEPS = 16;
  const int LIGHT_STEPS = 5;
  float ds = u_thickness / float(STEPS);
  float heightBase = 0.0;

  float transmittance = 1.0;
  vec3  radiance = vec3(0.0);

  vec3 V = vec3(0.0, -1.0, 0.0);
  float cosTheta = clamp(dot(normalize(-V), normalize(u_sunDir)), -1.0, 1.0);
  float phase = hgPhase(cosTheta, 0.7);

  for (int i = 0; i < STEPS; i++) {
    float h = heightBase + (float(i) + 0.5) * ds;
    vec3 p = vec3(warped, h * 0.8 + 10.0);
    float base = fbm3(p);
    float d = smoothstep(u_coverage, 1.0, base);
    float y = (float(i) + 0.5) / float(STEPS);
    float dome = exp(-4.0 * (y - 0.5) * (y - 0.5));
    d *= dome;
    d *= mix(0.6, 1.0, cover);
    d *= u_density;

    if (d > 0.001) {
      float lightT = 1.0;
      vec3 lp = p;
      float lds = (u_thickness * 0.8) / float(LIGHT_STEPS);
      vec3 ldir = normalize(u_sunDir);
      for (int j = 0; j < LIGHT_STEPS; j++) {
        lp += ldir * lds;
        float ld = smoothstep(u_coverage, 1.0, fbm3(lp));
        float ly = float(j) / float(LIGHT_STEPS);
        float ldome = exp(-4.0 * (ly - 0.2) * (ly - 0.2));
        ld *= ldome * u_density;
        lightT *= exp(-u_lightAbsorption * ld * lds);
      }

      vec3 scatter = u_sunColor * phase * lightT * d * ds;
      radiance += transmittance * scatter;
      transmittance *= exp(-d * ds);
      if (transmittance < 0.01) break;
    }
  }

  float alpha = clamp(1.0 - transmittance, 0.0, 1.0);
  vec3 cloudColor = mix(vec3(1.05), vec3(1.1, 1.1, 1.12), 0.2);
  vec3 color = cloudColor * radiance;

  gl_FragColor = vec4(color, alpha);
}
