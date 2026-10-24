import { Color, Mesh, ShaderMaterial, SphereGeometry, Vector3 } from "three";

export function createBubbleShell() {
  const geometry = new SphereGeometry(1, 48, 32);
  const material = new ShaderMaterial({
    transparent: true,
    depthWrite: false,
    uniforms: {
      stretch: { value: new Vector3() },
      time: { value: 0 },
      tint: { value: new Color(0.72, 0.9, 1) },
    },
    vertexShader: `
      uniform vec3 stretch;
      varying vec3 normalView;
      varying vec3 viewDirection;
      void main() {
        vec3 point = position;
        float amount = length(stretch);
        if (amount > 0.0001) {
          vec3 direction = stretch / amount;
          point += direction * max(dot(point, direction), 0.0) * amount;
        }
        vec4 view = modelViewMatrix * vec4(point, 1.0);
        normalView = normalize(normalMatrix * normal);
        viewDirection = -view.xyz;
        gl_Position = projectionMatrix * view;
      }
    `,
    fragmentShader: `
      uniform vec3 tint;
      uniform float time;
      varying vec3 normalView;
      varying vec3 viewDirection;
      void main() {
        vec3 n = normalize(normalView);
        float facing = clamp(dot(n, normalize(viewDirection)), 0.0, 1.0);
        float rim = pow(1.0 - facing, 2.6);
        vec3 phase = vec3(0.0, 0.33, 0.67) + rim * 1.3 + time * 0.04;
        vec3 sheen = 0.55 + 0.45 * cos(6.28318 * phase);
        vec3 colour = mix(tint, sheen, 0.45 * smoothstep(0.05, 0.6, rim));
        float mainSpot = smoothstep(0.92, 0.975, dot(n, normalize(vec3(-0.5, 0.62, 0.6))));
        float sideSpot = smoothstep(0.965, 0.99, dot(n, normalize(vec3(0.55, -0.5, 0.67))));
        float spot = (mainSpot + sideSpot * 0.45) * 0.85;
        colour = mix(colour, vec3(1.0), clamp(spot + rim * 0.35, 0.0, 1.0));
        gl_FragColor = vec4(colour, clamp(0.03 + rim * 0.9 + spot, 0.0, 1.0));
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
  });
  const mesh = new Mesh(geometry, material);
  return {
    mesh,
    update(radius: number, x: number, y: number, seconds: number): void {
      mesh.scale.setScalar(Math.max(0.001, radius));
      material.uniforms.stretch.value.set(x, y, 0);
      material.uniforms.time.value = seconds;
    },
    dispose(): void {
      geometry.dispose();
      material.dispose();
    },
  };
}
