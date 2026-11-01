// Top-down map drawn from the zone's navmesh, with the player, their target and a trail on top.
//
// Coordinates are the game's: x runs east, z runs north, and y is height with negative up. North is
// drawn up, so a world point (x, z) lands on screen at x right and z up - that is, the canvas is
// drawn in (x, -z) space.
//
// Rotation is the server's 0-255 byte. utils.cpp's worldAngle sets it to -atan2(dz, dx) * 128 / pi,
// so facing rot means a world heading of angle -rot * pi / 128 from east; with z flipped for the
// screen, that is screen angle +rot * pi / 128.

const POLYFLAG_SWIM = 0x0002;

// How far above the player ground has to be before "This floor" treats it as overhead - a walkway
// or upper storey - and draws it see-through on top, so the floor the player is on shows beneath
// it. Ground below the player is always drawn solid: in a multi-level zone it sits under the
// player's floor anyway, and in an open one it is just downhill. Stacked walkways are a few yalms
// apart, so this stays tighter than a floor-to-floor gap.
const OVERHEAD_CLEARANCE = 6;
const OVERHEAD_ALPHA = 0.22;

// Rebuild the floor layers only once the player's height has moved this far, not every step.
const REBUILD_HEIGHT_DELTA = 2;

const ELEVATION_STEPS = 16;
const TRAIL_MAX_POINTS = 600;
const TRAIL_MIN_STEP = 0.75;
const MIN_SCALE = 0.15;
const MAX_SCALE = 40;

function elevationColour(t, alpha = 1) {
    // Low ground a dark slate, high ground a pale sand, so slopes read as a gradient.
    const hue = 215 - t * 175;
    const saturation = 16 + t * 22;
    const lightness = 24 + t * 34;
    return `hsla(${hue.toFixed(0)}, ${saturation.toFixed(0)}%, ${lightness.toFixed(0)}%, ${alpha})`;
}

const WATER_COLOUR = '#1f4f7a';

export class MapView {
    constructor(canvas, { onFollowChange } = {}) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.onFollowChange = onFollowChange ?? (() => {});

        this.mesh = null;
        this.layers = null;
        this.layersBuiltAtY = null;

        this.player = null;
        this.target = null;
        this.trail = [];

        this.view = { cx: 0, cz: 0, scale: 2 };
        this.follow = true;
        this.floorOnly = true;
        this.showTrail = true;
        this.dimPlayer = false;

        this.dirty = true;
        this.width = 0;
        this.height = 0;

        new ResizeObserver(() => this.resize()).observe(canvas);
        this.bindPointer();
        this.resize();

        const frame = () => {
            if (this.dirty) {
                this.dirty = false;
                this.draw();
            }

            requestAnimationFrame(frame);
        };

        requestAnimationFrame(frame);
    }

    // State

    setMesh(mesh) {
        this.mesh = mesh;
        this.layers = null;
        this.trail = [];
        this.fit();
        this.dirty = true;
    }

    setPlayer(position) {
        const previous = this.player;
        this.player = position;

        if (position) {
            const last = this.trail[this.trail.length - 1];
            if (!last || Math.hypot(position.x - last.x, position.z - last.z) >= TRAIL_MIN_STEP) {
                this.trail.push({ x: position.x, z: position.z });
                if (this.trail.length > TRAIL_MAX_POINTS) {
                    this.trail.shift();
                }
            }

            if (this.follow) {
                this.view.cx = position.x;
                this.view.cz = position.z;
            }

            if (this.floorOnly && (this.layersBuiltAtY === null ||
                Math.abs(position.y - this.layersBuiltAtY) >= REBUILD_HEIGHT_DELTA)) {
                this.layers = null;
            }
        }

        if (!previous && position && this.follow) {
            this.fit();
        }

        this.dirty = true;
    }

    setTarget(target) {
        this.target = target;
        this.dirty = true;
    }

    setFollow(follow) {
        this.follow = follow;
        if (follow && this.player) {
            this.view.cx = this.player.x;
            this.view.cz = this.player.z;
        }

        this.dirty = true;
    }

    setFloorOnly(floorOnly) {
        this.floorOnly = floorOnly;
        this.layers = null;
        this.dirty = true;
    }

    setShowTrail(showTrail) {
        this.showTrail = showTrail;
        this.dirty = true;
    }

    clearTrail() {
        this.trail = [];
        this.dirty = true;
    }

    // Frame the player at a comfortable zoom, or the whole zone when there is no player yet.
    fit() {
        if (this.player) {
            this.view.cx = this.player.x;
            this.view.cz = this.player.z;
            this.view.scale = 3;
        } else if (this.mesh) {
            const { minX, maxX, minZ, maxZ } = this.mesh.bounds;
            this.view.cx = (minX + maxX) / 2;
            this.view.cz = (minZ + maxZ) / 2;
            const span = Math.max(maxX - minX, maxZ - minZ, 1);
            this.view.scale = Math.min(this.width, this.height) / span * 0.9;
        }

        this.dirty = true;
    }

    // Input

    resize() {
        const rect = this.canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        this.width = rect.width;
        this.height = rect.height;
        this.canvas.width = Math.round(rect.width * dpr);
        this.canvas.height = Math.round(rect.height * dpr);
        this.dirty = true;
    }

    screenToWorld(sx, sy) {
        return {
            x: (sx - this.width / 2) / this.view.scale + this.view.cx,
            z: -((sy - this.height / 2) / this.view.scale) + this.view.cz,
        };
    }

    worldToScreen(x, z) {
        return {
            x: (x - this.view.cx) * this.view.scale + this.width / 2,
            y: (this.view.cz - z) * this.view.scale + this.height / 2,
        };
    }

    bindPointer() {
        let drag = null;

        this.canvas.addEventListener('pointerdown', (event) => {
            drag = { x: event.clientX, y: event.clientY };
            this.canvas.setPointerCapture(event.pointerId);
            this.canvas.classList.add('dragging');
        });

        this.canvas.addEventListener('pointermove', (event) => {
            if (!drag) {
                return;
            }

            const dx = event.clientX - drag.x;
            const dy = event.clientY - drag.y;
            if (dx === 0 && dy === 0) {
                return;
            }

            // Panning by hand means the user wants to look somewhere else, so stop following.
            if (this.follow) {
                this.follow = false;
                this.onFollowChange(false);
            }

            this.view.cx -= dx / this.view.scale;
            this.view.cz += dy / this.view.scale;
            drag = { x: event.clientX, y: event.clientY };
            this.dirty = true;
        });

        const endDrag = () => {
            drag = null;
            this.canvas.classList.remove('dragging');
        };

        this.canvas.addEventListener('pointerup', endDrag);
        this.canvas.addEventListener('pointercancel', endDrag);

        this.canvas.addEventListener('wheel', (event) => {
            event.preventDefault();

            const rect = this.canvas.getBoundingClientRect();
            const sx = event.clientX - rect.left;
            const sy = event.clientY - rect.top;
            const before = this.screenToWorld(sx, sy);

            const factor = Math.exp(-event.deltaY * 0.0015);
            this.view.scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, this.view.scale * factor));

            // Zoom about the cursor, unless following - then the player stays centred.
            if (!this.follow) {
                const after = this.screenToWorld(sx, sy);
                this.view.cx += before.x - after.x;
                this.view.cz += before.z - after.z;
            }

            this.dirty = true;
        }, { passive: false });
    }

    // Drawing

    // Group polygons into a handful of Path2Ds by fill colour, so a zone of tens of thousands of
    // polygons draws in a dozen fill calls. Paths are built in (x, -z) world space and the canvas
    // transform does the rest, so panning and zooming never rebuild them.
    buildLayers() {
        const { verts, polys, bounds } = this.mesh;
        const minElevation = -bounds.maxY;
        const elevationRange = Math.max(bounds.maxY - bounds.minY, 1);
        const playerY = this.player?.y;
        const splitOverhead = this.floorOnly && playerY !== undefined;

        const paths = new Map();
        const pathFor = (key) => {
            if (!paths.has(key)) {
                paths.set(key, new Path2D());
            }

            return paths.get(key);
        };

        for (const poly of polys) {
            const flags = poly[0];

            let sumY = 0;
            for (let i = 1; i < poly.length; i++) {
                sumY += verts[poly[i] * 3 + 1];
            }

            const avgY = sumY / (poly.length - 1);

            // Negative y is up, so ground overhead has a y well below the player's.
            const overhead = splitOverhead && avgY < playerY - OVERHEAD_CLEARANCE;
            const t = (-avgY - minElevation) / elevationRange;
            const step = Math.min(ELEVATION_STEPS - 1, Math.max(0, Math.floor(t * ELEVATION_STEPS)));

            let key;
            if (overhead) {
                key = `o${step}`;
            } else if (flags & POLYFLAG_SWIM) {
                key = 'water';
            } else {
                key = `e${step}`;
            }

            const path = pathFor(key);
            const first = poly[1] * 3;
            path.moveTo(verts[first], -verts[first + 2]);
            for (let i = 2; i < poly.length; i++) {
                const v = poly[i] * 3;
                path.lineTo(verts[v], -verts[v + 2]);
            }

            path.closePath();
        }

        // Lowest first, so where floors overlap the higher one is drawn over the lower; overhead
        // ground last of all, see-through, so it veils rather than hides the player's floor.
        const layers = [];
        const addLayer = (key, colour, stroke) => {
            if (paths.has(key)) {
                layers.push({ path: paths.get(key), colour, stroke });
            }
        };

        for (let step = 0; step < ELEVATION_STEPS; step++) {
            addLayer(`e${step}`, elevationColour(step / (ELEVATION_STEPS - 1)), true);
        }

        addLayer('water', WATER_COLOUR, true);

        for (let step = 0; step < ELEVATION_STEPS; step++) {
            addLayer(`o${step}`, elevationColour(step / (ELEVATION_STEPS - 1), OVERHEAD_ALPHA), false);
        }

        this.layers = layers;
        this.layersBuiltAtY = playerY ?? null;
    }

    draw() {
        const { ctx } = this;
        const dpr = window.devicePixelRatio || 1;

        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.fillStyle = '#0b0e12';
        ctx.fillRect(0, 0, this.width, this.height);

        if (this.mesh) {
            if (!this.layers) {
                this.buildLayers();
            }

            const { scale, cx, cz } = this.view;
            ctx.save();
            ctx.translate(this.width / 2, this.height / 2);
            ctx.scale(scale, scale);
            ctx.translate(-cx, cz);

            // Stroking each solid layer in its own colour closes the hairline seams antialiasing
            // leaves between neighbouring polygons. See-through layers are not stroked: there the
            // overlapping strokes would draw every triangle edge.
            ctx.lineWidth = 1 / scale;
            ctx.lineJoin = 'round';
            for (const layer of this.layers) {
                ctx.fillStyle = layer.colour;
                ctx.fill(layer.path);
                if (layer.stroke) {
                    ctx.strokeStyle = layer.colour;
                    ctx.stroke(layer.path);
                }
            }

            ctx.restore();
        }

        if (this.showTrail && this.trail.length > 1) {
            ctx.beginPath();
            this.trail.forEach((point, i) => {
                const s = this.worldToScreen(point.x, point.z);
                if (i === 0) {
                    ctx.moveTo(s.x, s.y);
                } else {
                    ctx.lineTo(s.x, s.y);
                }
            });

            ctx.strokeStyle = 'rgba(242, 193, 78, 0.45)';
            ctx.lineWidth = 2;
            ctx.lineJoin = 'round';
            ctx.stroke();
        }

        if (this.player && this.target) {
            const p = this.worldToScreen(this.player.x, this.player.z);
            const t = this.worldToScreen(this.target.x, this.target.z);

            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(t.x, t.y);
            ctx.strokeStyle = 'rgba(230, 80, 70, 0.6)';
            ctx.lineWidth = 1.5;
            ctx.setLineDash([4, 4]);
            ctx.stroke();
            ctx.setLineDash([]);

            ctx.beginPath();
            ctx.arc(t.x, t.y, 6, 0, Math.PI * 2);
            ctx.fillStyle = '#e65046';
            ctx.fill();
            ctx.strokeStyle = '#0b0e12';
            ctx.lineWidth = 2;
            ctx.stroke();
        }

        if (this.player) {
            this.drawPlayer();
        }
    }

    drawPlayer() {
        const { ctx } = this;
        const p = this.worldToScreen(this.player.x, this.player.z);
        const angle = (this.player.rot ?? 0) * Math.PI / 128;

        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.globalAlpha = this.dimPlayer ? 0.4 : 1;

        // A soft halo so the marker reads against any floor colour.
        ctx.beginPath();
        ctx.arc(0, 0, 14, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(242, 193, 78, 0.18)';
        ctx.fill();

        ctx.rotate(angle);
        ctx.beginPath();
        ctx.moveTo(12, 0);
        ctx.lineTo(-7, 7);
        ctx.lineTo(-3, 0);
        ctx.lineTo(-7, -7);
        ctx.closePath();
        ctx.fillStyle = '#f2c14e';
        ctx.fill();
        ctx.strokeStyle = '#0b0e12';
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.restore();
    }
}
