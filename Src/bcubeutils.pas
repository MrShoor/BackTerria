unit bCubeUtils;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, avRes, avTypes, mutils;

{$I bshaders.inc}

type
  TEnviroment = packed record
    Radiance  : TavTexture;
    Irradiance: TavTexture;
  end;

  { TbCubeUtils }

  TbCubeUtils = class(TavMainRenderChild)
  private
    FCubeMatrices: TMat4Arr;
    FProgram_Irradiance: TavProgram;
    FProgram_Radiance: TavProgram;
    FProgram_LUT: TavProgram;

    FFBO: TavFrameBuffer;

    function GetFBO: TavFrameBuffer;
    function GetIrradianceProgram: TavProgram;
    function GetRadianceProgram: TavProgram;
    function GetLUTProgram: TavProgram;
  public
    procedure GenIrradianceFromCube(const ASrcCubeTexture: TavTexture; const ADestCubeTexture: TavTexture; const ADestSize: Integer);
    procedure GenRadianceFromCube(const ASrcCubeTexture: TavTexture; const ADestCubeTexture: TavTexture; const ADestSize: Integer);
    procedure GenLUTbrdf(const ADestTexture: TavTexture; const ALUTSize: Integer);

    procedure GenEnviromentFromCube(var AEnv: TEnviroment; const AEnvOwner: TavMainRenderChild; const ACubeMapFileName: string);
  public
    procedure InvalidateShaders;
    procedure AfterConstruction; override;
  end;



implementation

uses
  avTexLoader;

{ TbCubeUtils }

function TbCubeUtils.GetFBO: TavFrameBuffer;
begin
  if FFBO = nil then
    FFBO := TavFrameBuffer.Create(Self);
  Result := FFBO;
end;

function TbCubeUtils.GetIrradianceProgram: TavProgram;
begin
  if FProgram_Irradiance = nil then
  begin
    FProgram_Irradiance := TavProgram.Create(Self);
    FProgram_Irradiance.Load('irradiance_gen', SHADERS_FROMRES, SHADERS_DIR);
  end;
  Result := FProgram_Irradiance;
end;

function TbCubeUtils.GetRadianceProgram: TavProgram;
begin
  if FProgram_Radiance = nil then
  begin
    FProgram_Radiance := TavProgram.Create(Self);
    FProgram_Radiance.Load('radiance_gen', SHADERS_FROMRES, SHADERS_DIR);
  end;
  Result := FProgram_Radiance;
end;

function TbCubeUtils.GetLUTProgram: TavProgram;
begin
  if FProgram_LUT = nil then
  begin
    FProgram_LUT := TavProgram.Create(Self);
    FProgram_LUT.Load('lut_gen', SHADERS_FROMRES, SHADERS_DIR);
  end;
  Result := FProgram_LUT;
end;

procedure TbCubeUtils.GenIrradianceFromCube(const ASrcCubeTexture: TavTexture; const ADestCubeTexture: TavTexture; const ADestSize: Integer);
var prog: TavProgram;
    fbo : TavFrameBuffer;
    oldfbo: TavFrameBuffer;
begin
  prog := GetIrradianceProgram();
  fbo := GetFBO();

  fbo.SetColor(0, ADestCubeTexture, 0, 0, 6);
  fbo.FrameRect := RectI(0, 0, ADestSize, ADestSize);
  oldfbo := fbo.Select();

  prog.Select();
  prog.SetUniform('Cube', ASrcCubeTexture, Sampler_LinearNoMips);
  prog.SetUniform('viewProjInv', @FCubeMatrices[0], 6);
  prog.Draw(ptPoints, cmNone, false, 0, 0, 6);

  if oldfbo <> nil then
    oldfbo.Select();
end;

procedure TbCubeUtils.GenRadianceFromCube(const ASrcCubeTexture: TavTexture; const ADestCubeTexture: TavTexture; const ADestSize: Integer);
var prog: TavProgram;
    fbo : TavFrameBuffer;
    oldfbo: TavFrameBuffer;
    i: Integer;
begin
  oldfbo := nil;
  prog := GetRadianceProgram();
  fbo := GetFBO();

  ADestCubeTexture.TexData := EmptyTexData(ADestSize, ADestSize, 6, ADestCubeTexture.TargetFormat, True);
  ADestCubeTexture.Build;

  for i := 0 to ADestCubeTexture.MipsCount - 1 do
  begin
    fbo.SetColor(0, ADestCubeTexture, i, 0, 6);
    fbo.FrameRect := RectI(0, 0, ADestSize shr i, ADestSize shr i);
    if i = 0 then
      oldfbo := fbo.Select(False)
    else
      fbo.Select(False);

    prog.Select();
    prog.SetUniform('Cube', ASrcCubeTexture, Sampler_LinearNoMips);
    prog.SetUniform('viewProjInv', @FCubeMatrices[0], 6);
    prog.SetUniform('uRoughness', i / (ADestCubeTexture.MipsCount - 1));
    prog.Draw(ptPoints, cmNone, false, 0, 0, 6);
  end;

  if oldfbo <> nil then
    oldfbo.Select();
end;

procedure TbCubeUtils.GenLUTbrdf(const ADestTexture: TavTexture; const ALUTSize: Integer);
var prog: TavProgram;
    fbo : TavFrameBuffer;
    oldfbo: TavFrameBuffer;
begin
  prog := GetLUTProgram;
  fbo := GetFBO;
  fbo.SetColor(0, ADestTexture);
  fbo.FrameRect := RectI(0, 0, ALUTSize, ALUTSize);
  oldfbo := fbo.Select();

  prog.Select();
  prog.Draw(ptTriangleStrip, cmNone, false, 0, 0, 4);

  if oldfbo <> nil then
    oldfbo.Select();
end;

procedure TbCubeUtils.GenEnviromentFromCube(var AEnv: TEnviroment; const AEnvOwner: TavMainRenderChild; const ACubeMapFileName: string);
var cube: TavTexture;
    oldBlendState: Boolean;
begin
  if AEnv.Irradiance = nil then
  begin
    AEnv.Irradiance := TavTexture.Create(AEnvOwner);
    AEnv.Irradiance.TargetFormat := TTextureFormat.RGBA16f;
  end;

  if AEnv.Radiance = nil then
  begin
    AEnv.Radiance := TavTexture.Create(AEnvOwner);
    AEnv.Radiance.TargetFormat := TTextureFormat.RGBA16f;
  end;

  cube := TavTexture.Create(Self);
  try
    cube.TargetFormat := TTextureFormat.RGBA16f;
    cube.TexData := LoadTexture(ACubeMapFileName);

    oldBlendState := Main.States.Blending[0];
    Main.States.Blending[0] := False;
    GenIrradianceFromCube(cube, AEnv.Irradiance, 16);
    GenRadianceFromCube(cube, AEnv.Radiance, 128);
    Main.States.Blending[0] := oldBlendState;
  finally
    FreeAndNil(cube);
  end;
end;

procedure TbCubeUtils.InvalidateShaders;
begin
  if FProgram_Irradiance <> nil then
    FProgram_Irradiance.Invalidate;
  if FProgram_Radiance <> nil then
    FProgram_Radiance.Invalidate;
  if FProgram_LUT <> nil then
    FProgram_LUT.Invalidate;
end;

procedure TbCubeUtils.AfterConstruction;

  function CalcPerspectiveMatrix: TMat4;
  const fFOV = 0.5 * Pi;
  const fAspect = 1.0;
  var w, h, Q: Single;
      DepthSize: Single;
      NearPlane, FarPlane: Single;
  begin
    FarPlane := 1.0;
    NearPlane := 0.1;
    h := (cos(fFOV/2)/sin(fFOV/2));
    w := fAspect * h;
    Q := 1.0/(NearPlane - FarPlane);
    DepthSize := 1;//ADepthRange.y - ADepthRange.x;

    ZeroClear(Result, SizeOf(Result));
    Result.f[0, 0] := w;
    Result.f[1, 1] := h;
    Result.f[2, 2] := - DepthSize * FarPlane * Q;//ADepthRange.x - DepthSize * FarPlane * Q;
    Result.f[2, 3] := 1.0;
    Result.f[3, 2] := DepthSize * NearPlane * FarPlane * Q;
  end;

var mProj: TMat4;
    i: Integer;
    mView: array [0..5] of TMat4;

begin
  inherited AfterConstruction;

  mProj := CalcPerspectiveMatrix;

  for i := 0 to 5 do mView[i] := IdentityMat4;

  SetViewMatrix(mView[0], Vec(0,0,0), Vec( 100, 0, 0), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_X
  SetViewMatrix(mView[1], Vec(0,0,0), Vec(-100, 0, 0), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_X
  SetViewMatrix(mView[2], Vec(0,0,0), Vec(0,  100, 0), Vec(0, 0, -1)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Y
  SetViewMatrix(mView[3], Vec(0,0,0), Vec(0, -100, 0), Vec(0, 0, 1)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Y
  SetViewMatrix(mView[4], Vec(0,0,0), Vec(0, 0,  100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Z
  SetViewMatrix(mView[5], Vec(0,0,0), Vec(0, 0, -100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Z

  SetLength(FCubeMatrices, 6);
  for i := 0 to 5 do
    FCubeMatrices[i] := Inv(mView[i]*mProj);
end;

end.

