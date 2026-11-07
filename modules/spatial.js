import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js';

const SHAPES = {
    icosahedron: () => new THREE.IcosahedronGeometry(2, 1),
    octahedron: () => new THREE.OctahedronGeometry(2, 1),
    dodecahedron: () => new THREE.DodecahedronGeometry(2, 0),
    torus: () => new THREE.TorusGeometry(1.6, 0.6, 16, 64),
    torusknot: () => new THREE.TorusKnotGeometry(1.4, 0.45, 128, 16)
};

export class SpatialInterface {
    constructor(containerId) {
        this.container = document.getElementById(containerId) || document.body;
        this.reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        try {
            this.renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
        } catch (e) {
            return; // WebGL unavailable: terminal still works
        }
        this.scene = new THREE.Scene();
        this.camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        this.init();
    }

    init() {
        this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        this.renderer.setSize(window.innerWidth, window.innerHeight);
        Object.assign(this.renderer.domElement.style, {
            position: 'fixed', top: '0', left: '0', zIndex: '-1', pointerEvents: 'none'
        });
        this.container.appendChild(this.renderer.domElement);

        this.material = new THREE.MeshBasicMaterial({ color: 0x00ffcc, wireframe: true });
        this.mesh = new THREE.Mesh(SHAPES.icosahedron(), this.material);
        this.scene.add(this.mesh);

        // starfield particles
        const pts = new Float32Array(900);
        for (let i = 0; i < pts.length; i++) pts[i] = (Math.random() - 0.5) * 40;
        const g = new THREE.BufferGeometry();
        g.setAttribute('position', new THREE.BufferAttribute(pts, 3));
        this.starMat = new THREE.PointsMaterial({ color: 0x00ffcc, size: 0.05 });
        this.stars = new THREE.Points(g, this.starMat);
        this.scene.add(this.stars);

        this.camera.position.z = 5;
        window.addEventListener('resize', () => this.onWindowResize());
        window.addEventListener('pointermove', e => {
            this.tx = (e.clientX / window.innerWidth - 0.5) * 0.8;
            this.ty = (e.clientY / window.innerHeight - 0.5) * 0.8;
        });
        this.tx = this.ty = 0;
        this.animate();
    }

    setTheme(t) {
        if (!this.mesh) return;
        this.material.color.setHex(t.accent);
        this.starMat.color.setHex(t.accent);
        this.mesh.geometry.dispose();
        this.mesh.geometry = (SHAPES[t.shape] || SHAPES.icosahedron)();
    }

    animate() {
        requestAnimationFrame(() => this.animate());
        if (!this.reduced) {
            this.mesh.rotation.x += 0.002;
            this.mesh.rotation.y += 0.003;
            this.stars.rotation.y += 0.0004;
        }
        this.camera.position.x += (this.tx - this.camera.position.x) * 0.05;
        this.camera.position.y += (-this.ty - this.camera.position.y) * 0.05;
        this.camera.lookAt(0, 0, 0);
        this.renderer.render(this.scene, this.camera);
    }

    onWindowResize() {
        this.camera.aspect = window.innerWidth / window.innerHeight;
        this.camera.updateProjectionMatrix();
        this.renderer.setSize(window.innerWidth, window.innerHeight);
    }
}
