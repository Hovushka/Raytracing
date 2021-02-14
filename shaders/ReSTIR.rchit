#version 460
#extension GL_EXT_ray_tracing : enable
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_GOOGLE_include_directive : enable

#include "includes.glsl"

layout(location = 0) rayPayloadInEXT hitPayload hitValue;
layout(location = 2) rayPayloadEXT bool shadowed;
hitAttributeEXT vec3 attribs;

layout(binding = 0, set = 0) uniform accelerationStructureEXT topLevelAS;
layout(binding = 3, set = 0) uniform sampler2D texSamplers[];
layout(binding = 4, set = 0, scalar) buffer Vertices { Vertex v[]; } vertices[];
layout(binding = 5, set = 0) buffer Indices { uint i[]; } indices[];
layout(binding = 6, set = 0, scalar) buffer Materials { Material m; } materials[];
layout(binding = 7, set = 0, scalar) buffer Lights { Light l[]; } lights;
layout(binding = 8, set = 0) uniform Sizes {
    uint meshesSize;    
    uint lightsSize;
    uint M;
} sizes;
layout(binding = 9, set = 0, rgba8) uniform image2D presentReservoirs;
layout(binding = 10, set = 0, rgba8) uniform image2D vertexPositions;
layout(binding = 11, set = 0, rgba8) uniform image2D vertexNormals;
layout(binding = 12, set = 0, rgba8) uniform image2D vertexMaterials;

float shadowBias = 0.0001f;
float pi = 3.14159265f;
float albedo = 0.18f;
float specularPower = 35;

#include "shootRay.glsl"

float shadowRay(vec3 origin, float shadowBias, vec3 direction, float dist) {
	shadowed = true;

    traceRayEXT(topLevelAS, gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT, 
        0xFF, 0, 0, 1, origin, shadowBias, direction, dist, 2);

    if (shadowed)
        return 0.0f;
    else
        return 1.0f;
}

Vertex barycentricVertex(Vertex v0, Vertex v1, Vertex v2) {
    const vec3 barycentric = vec3(1.0f - attribs.x - attribs.y, attribs.x, attribs.y);
	vec3 origin    = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
    vec3 normal    = v0.normal * barycentric.x + v1.normal * barycentric.y + v2.normal * barycentric.z;
    vec2 texCoord  = v0.texCoord * barycentric.x + v1.texCoord * barycentric.y + v2.texCoord * barycentric.z;
    vec3 tangent   = v0.tangent * barycentric.x + v1.tangent * barycentric.y + v2.tangent * barycentric.z;
    vec3 bitangent = v0.bitangent * barycentric.x + v1.bitangent * barycentric.y + v2.bitangent * barycentric.z;

    return Vertex(origin, normal, texCoord, tangent, bitangent);
}

void save(vec2 UV, reservoir r) {
    vec4 data = vec4(r.X, r.Y, r.M, r.W);
	imageStore(presentReservoirs, ivec2(UV), data);
}

vec3 lightSample(Light light, float eps1, float eps2) {
    return light.a + eps1 * light.ab + eps2 * light.ac;
}

float desPdf(Light light, Vertex v, vec3 lpos) {
    float L_e = light.intensity;

    vec3  ldir = normalize(v.pos - lpos);
    float norm = length(v.pos - lpos);

    return dot(ldir, light.normal) / (norm * norm);
}

float lgtPdf(Light light) {
    return 2.0f / length(cross(light.ab, light.ac));
}

float calcPdf(Vertex v, float eps1, float eps2) {
    Light light = lights.l[uint(eps1 * sizes.lightsSize)];
    float reusedEps1 = eps1 - uint(eps1);
    vec3  lpos = lightSample(light, reusedEps1, eps2);

    return desPdf(light, v, lpos);
}

void update(inout reservoir r, float x_i, float a_i, float w_i) {
    r.Wsum += w_i;
    r.M += 1.0f;

    if (nextRand(hitValue.seed) < (w_i / r.Wsum)) {
        r.X = x_i;
        r.Y = a_i;
    }
}

void main()
{
    uint instance = nonuniformEXT(gl_InstanceCustomIndexEXT);

    // Ray direction
    vec3 rayDir = -normalize(gl_WorldRayDirectionEXT);

    if (instance >= sizes.meshesSize) {
        if (hitValue.diffuse) {
            hitValue.color = vec3(0.0f);
            return;
        }

        uint lightNo = instance - sizes.meshesSize;

        if (dot(rayDir, lights.l[lightNo].normal) > 0)
            hitValue.color = lights.l[lightNo].color * lights.l[lightNo].intensity;
        else
            hitValue.color = vec3(0.1f, 0.1f, 0.1f);
        return;
    }

    // Indices of the Triangle
    ivec3 index = ivec3(indices[instance].i[3 * gl_PrimitiveID + 0],
                      indices[instance].i[3 * gl_PrimitiveID + 1],
                      indices[instance].i[3 * gl_PrimitiveID + 2]);

    // Vertex of the Triangle
    Vertex v0 = vertices[instance].v[index.x];
    Vertex v1 = vertices[instance].v[index.y];
    Vertex v2 = vertices[instance].v[index.z];

    // Interpolated vertex
    Vertex v = barycentricVertex(v0, v1, v2);

    // Sample texture
    vec3 texColor = texture(texSamplers[nonuniformEXT(gl_InstanceCustomIndexEXT)], v.texCoord).xyz;

    // Sample material
    Material mat = materials[nonuniformEXT(gl_InstanceCustomIndexEXT)].m;

    // RIS
    reservoir r = { 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
    for (uint i = 0; i < sizes.M; i++) {
        float eps1 = nextRand(hitValue.seed);
        float eps2 = nextRand(hitValue.seed);

        float w = calcPdf(v, eps1, eps2) / lgtPdf(lights.l[uint(eps1)]);
        update(r, eps1, eps2, w);
    }
    r.W = r.Wsum / calcPdf(v, r.X, r.Y) / r.M;

    // Visibility
    Light light = lights.l[uint(r.X * sizes.lightsSize)];
    float reusedEps1 = r.X - uint(r.X);
    vec3  lpos = lightSample(light, reusedEps1, r.Y);

    vec3  ldir = normalize(v.pos - lpos);
    float norm = length(v.pos - lpos);
    float shadow = shadowRay(v.pos, shadowBias, -ldir, norm);

    if (shadow < 0.4f)
        r.W = 0.0f;

    save(gl_LaunchIDEXT.xy, r);
	imageStore(vertexPositions, ivec2(gl_LaunchIDEXT.xy), vec4(v.pos, 0.0f));
	imageStore(vertexNormals, ivec2(gl_LaunchIDEXT.xy), vec4(v.normal, 0.0f));
	imageStore(vertexMaterials, ivec2(gl_LaunchIDEXT.xy), vec4(texColor, 0.0f));
    hitValue.color = vec3(0.0f);
}
