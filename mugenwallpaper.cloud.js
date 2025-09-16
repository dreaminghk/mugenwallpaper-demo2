
function cloud(config) {
  const {
    canvasId = "clouds",
    targetDPR = 1.0,
    renderScale = 0.66,
    coverage = 0.55,
    density = 0.9,
    thickness = 1.2,
    scale = 0.3,
    lightAbsorption = 1.5,
    windSpeed = 0.006,
    windDir = [0.7, 0.2],
    sunColor = [1.0, 0.97, 0.92],
    targetFPS = 0,
  } = config || {};

  (async function () {
    const canvas = document.getElementById(canvasId);
    const gl = canvas.getContext("webgl", {
      alpha: true,
      antialias: true,
      premultipliedAlpha: false,
    });
    if (!gl) return;

    function resize() {
      const device = Math.max(1, window.devicePixelRatio || 1);
      const dpr = Math.min(device, targetDPR) * renderScale;
      const w = Math.floor(window.innerWidth * dpr);
      const h = Math.floor(window.innerHeight * dpr);
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
        canvas.style.width = window.innerWidth + "px";
        canvas.style.height = window.innerHeight + "px";
        gl.viewport(0, 0, w, h);
      }
    }

    Object.assign(canvas.style, {
      position: "fixed",
      left: "0",
      top: "0",
      width: "100vw",
      height: "100vh",
      pointerEvents: "none",
      zIndex: 1,
    });
    canvas.style.background = "transparent";

    async function loadShaders() {
      const [vsResp, fsResp] = await Promise.all([
        fetch("shaders/clouds.vert.glsl"),
        fetch("shaders/clouds.frag.glsl"),
      ]);
      if (!vsResp.ok || !fsResp.ok) {
        console.error(
          "Failed to load shader files",
          vsResp.status,
          fsResp.status
        );
        return { vs: null, fs: null };
      }
      const vs = await vsResp.text();
      const fs = await fsResp.text();
      return { vs, fs };
    }

    const shaderSources = await loadShaders();
    if (!shaderSources.vs || !shaderSources.fs) return;
    const vsSource = shaderSources.vs;
    const fsSource = shaderSources.fs;

    function compileShader(type, source) {
      const s = gl.createShader(type);
      gl.shaderSource(s, source);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        console.error("Shader compile error:", gl.getShaderInfoLog(s));
        gl.deleteShader(s);
        return null;
      }
      return s;
    }

    const vs = compileShader(gl.VERTEX_SHADER, vsSource);
    const fs = compileShader(gl.FRAGMENT_SHADER, fsSource);
    const prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.bindAttribLocation(prog, 0, "a_pos");
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      console.error("Program link error", gl.getProgramInfoLog(prog));
      return;
    }
    gl.useProgram(prog);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    const quad = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, quad);
    const verts = new Float32Array([-1, -1, 3, -1, -1, 3]);
    gl.bufferData(gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

    const u_time = gl.getUniformLocation(prog, "u_time");
    const u_resolution = gl.getUniformLocation(prog, "u_resolution");
    const u_wind = gl.getUniformLocation(prog, "u_wind");
    const u_sunDir = gl.getUniformLocation(prog, "u_sunDir");
    const u_sunColor = gl.getUniformLocation(prog, "u_sunColor");
    const u_coverage = gl.getUniformLocation(prog, "u_coverage");
    const u_density = gl.getUniformLocation(prog, "u_density");
    const u_thickness = gl.getUniformLocation(prog, "u_thickness");
    const u_scale = gl.getUniformLocation(prog, "u_scale");
    const u_lightAbsorption = gl.getUniformLocation(
      prog,
      "u_lightAbsorption"
    );

    let start = performance.now();

    const params = {
      coverage,
      density,
      thickness,
      scale,
      lightAbsorption,
    };

    function sunDirection(t) {
      const floatTime = t * 0.02;
      const elev = 0.8 - 0.15 * Math.cos(floatTime * 0.2);
      const azim = floatTime * 0.05;
      const x = Math.cos(elev) * Math.cos(azim);
      const y = Math.sin(elev);
      const z = Math.cos(elev) * Math.sin(azim);
      return [-x, -y, -z];
    }

    const minFrameTime = targetFPS > 0 ? 1.0 / targetFPS : 0.0;
    let lastRenderT = 0;

    function render() {
      resize();
      const now = performance.now();
      const t = (now - start) / 1000.0;
      if (minFrameTime > 0.0 && t - lastRenderT < minFrameTime) {
        requestAnimationFrame(render);
        return;
      }
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.useProgram(prog);
      gl.uniform1f(u_time, t);
      gl.uniform2f(u_resolution, canvas.width, canvas.height);
      const len = Math.hypot(windDir[0], windDir[1]) || 1.0;
      gl.uniform2f(
        u_wind,
        (windDir[0] / len) * windSpeed,
        (windDir[1] / len) * windSpeed
      );

      const sd = sunDirection(t);
      gl.uniform3f(u_sunDir, sd[0], sd[1], sd[2]);
      gl.uniform3f(u_sunColor, sunColor[0], sunColor[1], sunColor[2]);
      gl.uniform1f(u_coverage, params.coverage);
      gl.uniform1f(u_density, params.density);
      gl.uniform1f(u_thickness, params.thickness);
      gl.uniform1f(u_scale, params.scale);
      gl.uniform1f(u_lightAbsorption, params.lightAbsorption);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      lastRenderT = t;
      requestAnimationFrame(render);
    }

    resize();
    window.addEventListener("resize", resize);
    requestAnimationFrame(render);
  })();
}
