/*********************************************************************NVMH3****
*******************************************************************************
$Revision: #4 $

Copyright NVIDIA Corporation 2008
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THIS SOFTWARE IS PROVIDED
*AS IS* AND NVIDIA AND ITS SUPPLIERS DISCLAIM ALL WARRANTIES, EITHER EXPRESS
OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL NVIDIA OR ITS SUPPLIERS
BE LIABLE FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES
WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS,
BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR ANY OTHER PECUNIARY
LOSS) ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF
NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

% Texture-based remap of color space.  Color ramp textures can be
% easily generated by Photoshop and the PS "Curves" command.  The
% technique is described in "GPU Gems" in the section on color
% control.

keywords: image_processing virtual_machine


keywords: DirectX10
// Note that this version has twin versions of all techniques,
//   so that this single effect file can be used in *either*
//   DirectX9 or DirectX10

To learn more about shading, shaders, and to bounce ideas off other shader
    authors and users, visit the NVIDIA Shader Library Forums at:

    http://developer.nvidia.com/forums/

*******************************************************************************
******************************************************************************/

/*****************************************************************/
/*** HOST APPLICATION IDENTIFIERS ********************************/
/*** Potentially predefined by varying host environments *********/
/*****************************************************************/

// #define _XSI_		/* predefined when running in XSI */
// #define TORQUE		/* predefined in TGEA 1.7 and up */
// #define _3DSMAX_		/* predefined in 3DS Max */
#ifdef _3DSMAX_
int ParamID = 0x0003;		/* Used by Max to select the correct parser */
#endif /* _3DSMAX_ */
#ifdef _XSI_
#define Main Static		/* Technique name used for export to XNA */
#endif /* _XSI_ */

#ifndef FXCOMPOSER_VERSION	/* for very old versions */
#define FXCOMPOSER_VERSION 180
#endif /* FXCOMPOSER_VERSION */

#ifndef DIRECT3D_VERSION
#define DIRECT3D_VERSION 0x900
#endif /* DIRECT3D_VERSION */

#define FLIP_TEXTURE_Y	/* Different in OpenGL & DirectX */

/*****************************************************************/
/*** EFFECT-SPECIFIC CODE BEGINS HERE ****************************/
/*****************************************************************/
//
// Un-Comment the PROCEDURAL_TEXTURE macro to enable texture generation in
//      DirectX9 ONLY
// DirectX10 may not issue errors, but will generate no texture either
//
// #define PROCEDURAL_TEXTURE
//

// shared-surface access supported in Cg version
#include <include\\Quad.fxh>

float Script : STANDARDSGLOBAL <
    string UIWidget = "none";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
    string ScriptOutput = "color";
    string Script = "Technique=Technique?Main:Main10;";
> = 0.8;

// color and depth used for full-screen clears

float4 gClearColor <
    string UIWidget = "Color";
    string UIName = "Background";
> = {0,0,0,0};

float gClearDepth <string UIWidget = "none";> = 1.0;

///////////////////////////////////////////////////////////
/////////////////////////////////////// Tweakables ////////
///////////////////////////////////////////////////////////

QUAD_REAL gFade <
    string UIWidget = "slider";
    QUAD_REAL UIMin = 0.0f;
    QUAD_REAL UIMax = 1.0f;
    QUAD_REAL UIStep = 0.01f;
> = 1.0f;

///////////////////////////////////////////////////////////
/////////////////////////////////////// Textures //////////
///////////////////////////////////////////////////////////

#ifdef PROCEDURAL_TEXTURE
// assume "t" ranges from 0 to 1 safely
// brute-force this, it's running on the CPU
QUAD_REAL3 c_bezier(QUAD_REAL3 c0,
		    QUAD_REAL3 c1,
		    QUAD_REAL3 c2,
		    QUAD_REAL3 c3,
		    QUAD_REAL t)
{
    QUAD_REAL t2 = t*t;
    QUAD_REAL t3 = t2*t;
    QUAD_REAL nt = 1.0 - t;
    QUAD_REAL nt2 = nt*nt;
    QUAD_REAL nt3 = nt2 * nt;
    QUAD_REAL3 b = nt3*c0 + (3.0*t*nt2)*c1 + (3.0*t2*nt)*c2 + t3*c3;
    return b;
}

// function used to fill the volume noise texture
QUAD_REAL4 color_curve(QUAD_REAL2 Pos : POSITION) : COLOR
{
    QUAD_REAL3 kolor0 = QUAD_REAL3(0.0,0.0,0.0);
    QUAD_REAL3 kolor1 = QUAD_REAL3(0.8,0.3,0.0);
    QUAD_REAL3 kolor2 = QUAD_REAL3(0.7,0.7,0.9);
    QUAD_REAL3 kolor3 = QUAD_REAL3(1.0,0.9,1.0);
    QUAD_REAL3 sp = c_bezier(kolor0,kolor1,kolor2,kolor3,Pos.x);
    return QUAD_REAL4(sp,1);
}

texture gColorCurveTex  <
    string ResourceType = "2D";
    string function = "color_curve";
    string UIName = "Color Curve Ramp Texture";
    string UIWidget = "None";
    float2 Dimensions = { 256.0f, 4 };	// not 1, so visible in Texture View
>;
#else /* ! PROCEDURAL_TEXTURE */
texture gColorCurveTex  <
    string ResourceName="sample_color_curve.dds";
    string UIName = "Color Curve Ramp Texture";
    string ResourceType = "2D";
>;
#endif /* ! PROCEDURAL_TEXTURE */

sampler2D gColorCurveSampler = sampler_state 
{
#ifdef PROCEDUAL_TEXTURE
	Texture = <gProcColorCurveTex>;
#else /* ! PROCEDURAL_TEXTURE */
	Texture = <gColorCurveTex>;
#endif /* ! PROCEDURAL_TEXTURE */
    AddressU  = Clamp;        
    AddressV  = Clamp;
#if DIRECT3D_VERSION >= 0xa00
    Filter = MIN_MAG_MIP_LINEAR;
#else /* DIRECT3D_VERSION < 0xa00 */
    MinFilter = Linear;
    MipFilter = Linear;
    MagFilter = Linear;
#endif /* DIRECT3D_VERSION */
};

DECLARE_QUAD_TEX(gSceneTexture,gSceneSampler,"A8R8G8B8")
DECLARE_QUAD_DEPTH_BUFFER(DepthBuffer,"D24S8")

//////////////////////////////////////////////////////
/////////////////////////////////// pixel shader /////
//////////////////////////////////////////////////////

QUAD_REAL4 colorCurvePS(QuadVertexOutput IN,
		    uniform sampler2D SceneSampler,
		    uniform sampler2D ColorCurveSampler,
		    uniform QUAD_REAL Fade
) : COLOR {   
    QUAD_REAL3 scnColor = tex2D(SceneSampler, IN.UV).xyz;
    QUAD_REAL red = tex2D(ColorCurveSampler,QUAD_REAL2(scnColor.x,0)).x;
    QUAD_REAL grn = tex2D(ColorCurveSampler,QUAD_REAL2(scnColor.y,0)).y;
    QUAD_REAL blu = tex2D(ColorCurveSampler,QUAD_REAL2(scnColor.z,0)).z;
    QUAD_REAL3 newColor = QUAD_REAL3(red,grn,blu);
    QUAD_REAL3 result = lerp(scnColor,newColor,Fade);
    return QUAD_REAL4(result,1);
}  

///////////////////////////////////////
/// TECHNIQUES ////////////////////////
///////////////////////////////////////

//
// DirectX10 Version
//
#if DIRECT3D_VERSION >= 0xa00
//
// Standard DirectX10 Material State Blocks
//
RasterizerState DisableCulling { CullMode = NONE; };
DepthStencilState DepthEnabling { DepthEnable = TRUE; };
DepthStencilState DepthDisabling {
	DepthEnable = FALSE;
	DepthWriteMask = ZERO;
};
BlendState DisableBlend { BlendEnable[0] = FALSE; };

technique10 Main10 < string Script =
#ifndef SHARED_BG_IMAGE
    "RenderColorTarget0=gSceneTexture;"
    "RenderDepthStencilTarget=DepthBuffer;"
    "ClearSetColor=gClearColor;"
    "ClearSetDepth=gClearDepth;"
	"Clear=Color;"
	"Clear=Depth;"
    "ScriptExternal=Color;" // calls all "previous" techniques & materials
    "Pass=PostP0;";
#else /* defined(SHARED_BG_IMAGE)  - no nead to create one, COLLADA has done it for us  */
    "ClearSetColor=gClearColor;"
    "ClearSetDepth=gClearDepth;"
	"Clear=Color;"
	"Clear=Depth;"
    "Pass=PostP0;";
#endif /* SHARED_BG_IMAGE */
> {
    pass PostP0 < string Script =
	"RenderColorTarget0=;"
	"RenderDepthStencilTarget=;"
	"Draw=Buffer;";
    > {
        SetVertexShader( CompileShader( vs_4_0, ScreenQuadVS2(QuadTexelOffsets) ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, colorCurvePS(gSceneSampler,gColorCurveSampler,gFade) ) );
	    SetRasterizerState(DisableCulling);
	    SetDepthStencilState(DepthDisabling, 0);
	    SetBlendState(DisableBlend, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF);
    }
}
#endif /* DIRECT3D_VERSION >= 0xa00 */

//
// DirectX9 Version
//
technique Main < string Script =
#ifndef SHARED_BG_IMAGE
    "RenderColorTarget0=gSceneTexture;"
    "RenderDepthStencilTarget=DepthBuffer;"
    "ClearSetColor=gClearColor;"
    "ClearSetDepth=gClearDepth;"
	"Clear=Color;"
	"Clear=Depth;"
    "ScriptExternal=Color;" // calls all "previous" techniques & materials
    "Pass=PostP0;";
#else /* defined(SHARED_BG_IMAGE)  - no nead to create one, COLLADA has done it for us  */
    "ClearSetColor=gClearColor;"
    "ClearSetDepth=gClearDepth;"
	"Clear=Color;"
	"Clear=Depth;"
    "Pass=PostP0;";
#endif /* SHARED_BG_IMAGE */
> {
    pass PostP0 < string Script =
	"RenderColorTarget0=;"
	"RenderDepthStencilTarget=;"
	"Draw=Buffer;";
    > {
	VertexShader = compile vs_3_0 ScreenQuadVS2(QuadTexelOffsets);
		ZEnable = false;
		ZWriteEnable = false;
		AlphaBlendEnable = false;
		CullMode = None;
	PixelShader = compile ps_3_0 colorCurvePS(gSceneSampler,gColorCurveSampler,gFade);
    }
}

//////////////////////////////////////////////
/////////////////////////////////////// eof //
//////////////////////////////////////////////
