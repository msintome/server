// Reads the server's navmeshes/<Zone_Name>.nav files into plain polygons for drawing a top-down map.
//
// The navmesh is the walkable floor the server pathfinds on, in the server's own coordinates, so a
// position from the exporter lands on it exactly with no calibration. It is a schematic rather than
// the game's painted map, but it is right by construction and exists for every zone that has one.
//
// File layout, as written by CNavMesh::save (src/map/navmesh/navmesh.cpp), all little-endian:
//
//   NavMeshSetHeader  magic 'MSET', version 1, numTiles, dtNavMeshParams (28 bytes)  = 40 bytes
//   per tile:
//     NavMeshTileHeader  tileRef (uint32 - this build has DT_POLYREF64 off), dataSize  = 8 bytes
//     tile data          Detour's own layout, starting with a 100-byte dtMeshHeader:
//                          magic 'DNAV', version 7, x, y, layer, userId, polyCount @24,
//                          vertCount @28, ... bmin/bmax, bvQuantFactor
//                        then vertCount float[3] vertices,
//                        then polyCount 32-byte dtPoly records:
//                          firstLink u32, verts u16[6], neis u16[6], flags u16 @28,
//                          vertCount u8 @30, areaAndType u8 @31
//
// Only vertices and polygons are needed; the links, detail meshes and BV tree after them are
// skipped by jumping to the next tile with dataSize.
//
// Detour's axes are not the game's: CNavMesh::ToFFXIPos maps detour (x, y, z) to game
// (x, -y, -z), and that conversion is applied here so everything downstream is in game coordinates
// (x east, z north, and y height with negative up).

import fs from 'node:fs/promises';
import path from 'node:path';

const NAVMESHSET_MAGIC = 0x4d534554; // 'MSET'
const NAVMESHSET_VERSION = 1;
const DETOUR_MAGIC = 0x444e4156; // 'DNAV'
const DETOUR_VERSION = 7;

const SET_HEADER_SIZE = 40;
const TILE_HEADER_SIZE = 8;
const MESH_HEADER_SIZE = 100;
const POLY_SIZE = 32;
const VERTS_PER_POLY = 6;

const POLYTYPE_OFFMESH_CONNECTION = 1;

export const POLYFLAG_SWIM = 0x0002;
const POLYFLAG_DISABLED = 0x0010;

const round2 = (n) => Math.round(n * 100) / 100;

export function parseNavmesh(buf) {
    if (buf.readInt32LE(0) !== NAVMESHSET_MAGIC || buf.readInt32LE(4) !== NAVMESHSET_VERSION) {
        throw new Error('not an MSET v1 navmesh');
    }

    const numTiles = buf.readInt32LE(8);
    const verts = [];
    const polys = [];
    const bounds = {
        minX: Infinity, maxX: -Infinity,
        minY: Infinity, maxY: -Infinity,
        minZ: Infinity, maxZ: -Infinity,
    };

    let offset = SET_HEADER_SIZE;
    for (let tile = 0; tile < numTiles; tile++) {
        if (offset + TILE_HEADER_SIZE > buf.length) {
            break;
        }

        const tileRef = buf.readUInt32LE(offset);
        const dataSize = buf.readInt32LE(offset + 4);
        offset += TILE_HEADER_SIZE;

        // The loader stops at the first empty tile header too.
        if (!tileRef || !dataSize) {
            break;
        }

        const start = offset;
        offset += dataSize;

        if (buf.readInt32LE(start) !== DETOUR_MAGIC || buf.readInt32LE(start + 4) !== DETOUR_VERSION) {
            continue;
        }

        const polyCount = buf.readInt32LE(start + 24);
        const vertCount = buf.readInt32LE(start + 28);
        const base = verts.length / 3;

        const vertStart = start + MESH_HEADER_SIZE;
        for (let i = 0; i < vertCount; i++) {
            const p = vertStart + i * 12;
            const x = buf.readFloatLE(p);
            const y = -buf.readFloatLE(p + 4);
            const z = -buf.readFloatLE(p + 8);

            verts.push(round2(x), round2(y), round2(z));

            bounds.minX = Math.min(bounds.minX, x);
            bounds.maxX = Math.max(bounds.maxX, x);
            bounds.minY = Math.min(bounds.minY, y);
            bounds.maxY = Math.max(bounds.maxY, y);
            bounds.minZ = Math.min(bounds.minZ, z);
            bounds.maxZ = Math.max(bounds.maxZ, z);
        }

        const polyStart = vertStart + vertCount * 12;
        for (let i = 0; i < polyCount; i++) {
            const p = polyStart + i * POLY_SIZE;
            const flags = buf.readUInt16LE(p + 28);
            const count = buf.readUInt8(p + 30);
            const type = buf.readUInt8(p + 31) >> 6;

            // Off-mesh connections are two-point jump links, not floor, and disabled polys are
            // ones the server will not path over.
            if (type === POLYTYPE_OFFMESH_CONNECTION || flags & POLYFLAG_DISABLED || count < 3) {
                continue;
            }

            // [flags, i0, i1, ...], with indices into the flattened verts array.
            const poly = [flags];
            for (let v = 0; v < Math.min(count, VERTS_PER_POLY); v++) {
                poly.push(base + buf.readUInt16LE(p + 4 + v * 2));
            }

            polys.push(poly);
        }
    }

    for (const key of Object.keys(bounds)) {
        bounds[key] = round2(bounds[key]);
    }

    return { bounds, verts, polys };
}

// Zone names come from the client's request, so only accept the characters zone names use, and
// never let one climb out of the navmesh directory.
const ZONE_NAME = /^[A-Za-z0-9_\-[\]' ]+$/;

export class NavmeshCache {
    constructor(dir) {
        this.dir = dir;
        this.cache = new Map();
    }

    async get(zoneName) {
        if (!ZONE_NAME.test(zoneName) || zoneName.includes('..')) {
            return null;
        }

        if (!this.cache.has(zoneName)) {
            // Cache the promise, so two requests for the same zone share one parse.
            this.cache.set(zoneName, this.load(zoneName));
        }

        return this.cache.get(zoneName);
    }

    async load(zoneName) {
        const file = path.join(this.dir, `${zoneName}.nav`);
        try {
            return JSON.stringify(parseNavmesh(await fs.readFile(file)));
        } catch (err) {
            if (err.code !== 'ENOENT') {
                console.warn(`[navmesh] ${zoneName}: ${err.message}`);
            }

            return null;
        }
    }
}
