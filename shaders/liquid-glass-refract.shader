// =============================================================================
// Liquid Glass — véritable réfraction, pour obs-shaderfilter (plugin par
// exeldro : https://github.com/exeldro/obs-shaderfilter)
//
// CONTRAIREMENT à la stack HTML/CSS du reste du dossier (chat/, widgets/,
// music/, screens/), ce fichier n'est PAS servi par server.py et ne va PAS
// dans une source Navigateur OBS. C'est un filtre à appliquer DIRECTEMENT
// dans OBS, sur un Groupe contenant ta vraie source webcam — c'est la seule
// façon d'avoir accès aux pixels réels à déformer, ce qu'une page HTML ne
// peut jamais faire (voir README, section blur, pour l'explication complète
// de cette limite).
//
// ⚠️ Non testé de mon côté — je n'ai aucun accès à OBS pour compiler ou
// visualiser ce shader. La géométrie (SDF, gradient, réfraction) est solide
// mathématiquement, mais attends-toi à devoir ajuster avec moi si un détail
// de syntaxe ne passe pas sur ta version d'OBS.
//
// ---------------------------------------------------------------------------
// MISE EN PLACE
//
// 1. Installe le plugin obs-shaderfilter (si pas déjà fait) :
//    https://obsproject.com/forum/resources/shaderfilter.1736/
//    (ou via le gestionnaire de plugins si ta version d'OBS en a un)
//
// 2. Dans ta scène, groupe ta source webcam seule (clic droit → Grouper les
//    sources sélectionnées). Le filtre doit s'appliquer sur ce GROUPE, pas
//    sur la webcam directement — sinon `image` ne contiendrait que le flux
//    brut sans rien d'autre à composer autour.
//
// 3. Clic droit sur le groupe → Filtres → + → "Filtre Shader personnalisé
//    (User-defined shader)" (nom exact selon la version du plugin).
//
// 4. Dans les propriétés du filtre, coche "Charger le texte du shader depuis
//    un fichier" et pointe vers ce fichier — ou colle son contenu.
//
// 5. Les curseurs (frost, refraction_strength, etc.) apparaissent
//    automatiquement dans le panneau de propriétés du filtre : c'est ton
//    contrôle dépoli ↔ transparent, réglable en direct, sans toucher au
//    fichier.
// =============================================================================

uniform float frost<
    string label = "Dépoli (0 = verre clair, 1 = givré)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.35;

uniform float frost_blur_radius<
    string label = "Rayon du flou dépoli (px)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 24.0;
    float step = 0.5;
> = 6.0;

uniform float refraction_strength<
    string label = "Force de réfraction (px)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 40.0;
    float step = 0.5;
> = 10.0;

uniform float chromatic_aberration<
    string label = "Aberration chromatique (px)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 8.0;
    float step = 0.1;
> = 1.5;

uniform float edge_glow_intensity<
    string label = "Intensité du liseré lumineux";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.05;
> = 0.6;

uniform float edge_glow_width<
    string label = "Largeur du liseré (px)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 20.0;
    float step = 0.5;
> = 5.0;

uniform float3 tint_color<
    string label = "Teinte du verre";
    string widget_type = "color";
> = { 0.86, 0.83, 0.95 };

uniform float tint_strength<
    string label = "Force de la teinte";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.12;

uniform float thickness<
    string label = "Épaisseur de l'anneau (px)";
    string widget_type = "slider";
    float minimum = 4.0;
    float maximum = 200.0;
    float step = 1.0;
> = 40.0;

uniform float corner_radius_inner<
    string label = "Rayon intérieur (px, le trou webcam)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 200.0;
    float step = 1.0;
> = 32.0;

uniform float corner_radius_outer<
    string label = "Rayon extérieur (px) — 0 = coins bouchés (?corners=plug)";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 200.0;
    float step = 1.0;
> = 32.0;

// ---------------------------------------------------------------------------
// Géométrie : champ de distance signée (SDF) pour un rectangle arrondi,
// technique standard (Inigo Quilez). Négatif = dedans, positif = dehors.
// Calculée en pixels (pas en UV 0-1) pour que les coins restent des cercles
// parfaits quel que soit le ratio largeur/hauteur de la source — même souci
// que résolu en JS pour widgets/frame.html?corners=plug.
float sdRoundRect(float2 p, float2 half_size, float r)
{
    float2 q = abs(p) - half_size + r;
    return length(max(q, float2(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// SDF de l'anneau lui-même : extérieur moins trou intérieur (CSG standard).
// Négatif = dans la bande de verre. Positif = soit hors du cadre, soit dans
// le trou (webcam visible sans déformation).
float ringSDF(float2 p, float2 canvas_half, float2 center)
{
    float2 rel = p - center;
    float outer_d = sdRoundRect(rel, canvas_half, corner_radius_outer);
    float inner_d = sdRoundRect(rel, canvas_half - thickness, corner_radius_inner);
    return max(outer_d, -inner_d);
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 canvas_half = uv_size * 0.5;
    float2 center = canvas_half;
    float2 p = uv * uv_size;

    float d = ringSDF(p, canvas_half, center);

    // hors de l'anneau (dehors du cadre, ou dans le trou webcam) : pixel
    // d'origine inchangé, aucun coût de calcul supplémentaire
    if (d > 1.0)
    {
        return image.Sample(textureSampler, uv);
    }

    // gradient du SDF par différences finies → direction de "courbure" de
    // la lumière à cet endroit, comme la normale d'une vraie lentille
    float eps = 1.0;
    float2 grad = float2(
        ringSDF(p + float2(eps, 0.0), canvas_half, center) - ringSDF(p - float2(eps, 0.0), canvas_half, center),
        ringSDF(p + float2(0.0, eps), canvas_half, center) - ringSDF(p - float2(0.0, eps), canvas_half, center)
    );
    float grad_len = length(grad);
    float2 normal = (grad_len > 0.0001) ? grad / grad_len : float2(0.0, 0.0);

    // plus fort pile sur les bords (intérieur ET extérieur de la bande),
    // plus faible au milieu — comme le bombé réel d'un biseau de verre
    float edge_factor = 1.0 - smoothstep(0.0, thickness * 0.5, abs(d + thickness * 0.5));

    float2 refract_uv_offset = normal * refraction_strength * edge_factor * uv_pixel_interval;
    float2 uv_refracted = uv + refract_uv_offset;

    // échantillon net (verre clair)
    float4 sharp = image.Sample(textureSampler, uv_refracted);

    // échantillon flouté (verre dépoli) — flou en croix à 8 points, léger
    // mais suffisant pour lire comme "givré" une fois mélangé
    float4 blurred = float4(0.0, 0.0, 0.0, 0.0);
    float2 br = frost_blur_radius * uv_pixel_interval;
    blurred += image.Sample(textureSampler, uv_refracted + float2( br.x,  0.0));
    blurred += image.Sample(textureSampler, uv_refracted + float2(-br.x,  0.0));
    blurred += image.Sample(textureSampler, uv_refracted + float2( 0.0,  br.y));
    blurred += image.Sample(textureSampler, uv_refracted + float2( 0.0, -br.y));
    blurred += image.Sample(textureSampler, uv_refracted + br);
    blurred += image.Sample(textureSampler, uv_refracted - br);
    blurred += image.Sample(textureSampler, uv_refracted + float2(br.x, -br.y));
    blurred += image.Sample(textureSampler, uv_refracted + float2(-br.x, br.y));
    blurred *= 0.125;

    float4 glass = lerp(sharp, blurred, frost);

    // aberration chromatique : canaux R/G/B échantillonnés avec un léger
    // décalage le long de la normale — plus visible près des bords
    float2 ca = normal * chromatic_aberration * edge_factor * uv_pixel_interval;
    float r = lerp(
        image.Sample(textureSampler, uv_refracted + ca).r,
        blurred.r, frost);
    float b = lerp(
        image.Sample(textureSampler, uv_refracted - ca).b,
        blurred.b, frost);
    glass.r = r;
    glass.b = b;

    // teinte légère du verre
    glass.rgb = lerp(glass.rgb, tint_color, tint_strength);

    // liseré lumineux : brille près de d=0 (le contour précis de la bande,
    // intérieur comme extérieur)
    float glow = (1.0 - smoothstep(0.0, edge_glow_width, abs(d))) * edge_glow_intensity;
    glass.rgb += glow;

    glass.a = image.Sample(textureSampler, uv).a;
    return glass;
}
