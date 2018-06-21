unit bPostProcess;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, avRes, avTypes, mutils;

{$I bshaders.inc}

type

  { TavPostProcess }

  TavPostProcess = class (TavMainRenderChild)
  private
    FHammersleySphere: TVec4Arr;
    FResultFBO: TavFrameBuffer;

    FBlurProgram: TavProgram;
    FPostProcess: TavProgram;
    FRandomTex: TavTexture;

    FTempFBO16f: TavFrameBuffer;
    function GetResult0: TavTextureBase;
  protected
    procedure AfterRegister; override;
  public
    procedure InvalidateShaders;

    procedure DoPostProcess(AGbuffer: TavFrameBuffer);

    property Result0: TavTextureBase read GetResult0;
    property ResultFBO: TavFrameBuffer read FResultFBO;
  end;

implementation

uses
  avTexLoader, Math;

const
  Sampler_Depth : TSamplerInfo = (
    MinFilter  : tfNearest;
    MagFilter  : tfNearest;
    MipFilter  : tfNone;
    Anisotropy : 0;
    Wrap_X     : twClamp;
    Wrap_Y     : twClamp;
    Wrap_Z     : twClamp;
    Border     : (x: 1; y: 1; z: 1; w: 1);
    Comparison : cfNever;
  );

{ TavPostProcess }

function TavPostProcess.GetResult0: TavTextureBase;
begin
  Result := FResultFBO.GetColor(0);
end;

procedure TavPostProcess.AfterRegister;

  function GetRandomTextureData: ITextureData;
  const S = 4;
  var mip: ITextureMip;
      pv: PVec4;
      i: Integer;
      l: Single;
  begin
    Result := EmptyTexData(S, S, TTextureFormat.RGBA32f, false, True);
    mip := Result.MipData(0, 0);
    pv := PVec4(mip.Data);
    for i := 0 to S * S - 1 do
    begin
      pv^ := normalize(Vec(Random()-0.5, Random()-0.5, Random()-0.5, 0));
      Inc(pv);
    end;
  end;

var
  i: Integer;
  h: TVec2;

begin
  inherited AfterRegister;
  FResultFBO := Create_FrameBuffer(Self, [TTextureFormat.RGBA], [true]);

  FPostProcess := TavProgram.Create(Self);
  FPostProcess.Load('PostProcess1', SHADERS_FROMRES, SHADERS_DIR);
  FBlurProgram := TavProgram.Create(Self);
  FBlurProgram.Load('Blur', SHADERS_FROMRES, SHADERS_DIR);

  FRandomTex := TavTexture.Create(Self);
  FRandomTex.TargetFormat := TTextureFormat.RGBA32f;
  FRandomTex.TexData := GetRandomTextureData;

  FHammersleySphere := GenerateHammersleyPts(16);
  for i := 0 to Length(FHammersleySphere) - 1 do
  begin
    h := FHammersleySphere[i].xy;
    h.x := arccos(1.0-h.x);
    h.y := h.y*2*Pi;
    FHammersleySphere[i].xyz := Vec(sin(h.x) * cos(h.y), sin(h.x) * sin(h.y), cos(h.x));
  end;

  FTempFBO16f := Create_FrameBuffer(Self, [TTextureFormat.RGBA16f], [false]);
end;

procedure TavPostProcess.InvalidateShaders;
begin
  FPostProcess.Invalidate;
  FBlurProgram.Invalidate;
end;

procedure TavPostProcess.DoPostProcess(AGbuffer: TavFrameBuffer);
var blurstep: Single;
    Color, Normal, Depth: TavTextureBase;
begin
  Color := AGbuffer.GetColor(0);
  Normal := AGbuffer.GetColor(1);
  Depth := AGbuffer.GetDepth;

  Main.States.SetBlendFunctions(bfOne, bfOne);
  Main.States.DepthTest := False;

  blurstep := 1/1024;
  FTempFBO16f.FrameRect := AGbuffer.FrameRect;
  FTempFBO16f.Select();
  FTempFBO16f.Clear(0, Vec(0,0,0,0));
  FBlurProgram.Select();
  FBlurProgram.SetAttributes(nil, nil, nil);
  FBlurProgram.SetUniform('Color', Color, Sampler_Linear_NoAnisotropy);
  FBlurProgram.SetUniform('YLimit', 1.0);
  FBlurProgram.SetUniform('Direction', Vec(0,blurstep));
  FBlurProgram.SetUniform('ResultMult', 1.0);
  FBlurProgram.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);

  AGbuffer.Select();
  Main.States.ColorMask[1] := [];
  FBlurProgram.Select();
  FBlurProgram.SetAttributes(nil, nil, nil);
  FBlurProgram.SetUniform('Color', FTempFBO16f.GetColor(0), Sampler_Linear_NoAnisotropy);
  FBlurProgram.SetUniform('YLimit', 0.0);
  FBlurProgram.SetUniform('Direction', Vec(blurstep*AGbuffer.FrameRect.Size.x/AGbuffer.FrameRect.Size.y,0));
  FBlurProgram.SetUniform('ResultMult', 0.3);
  FBlurProgram.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);
  Main.States.ColorMask[1] := AllChanells;

  Main.States.SetBlendFunctions(bfSrcAlpha, bfInvSrcAlpha);

  FResultFBO.FrameRect := AGbuffer.FrameRect;
  FResultFBO.Select;

  FPostProcess.Select();
  FPostProcess.SetUniform('Color', Color, Sampler_NoFilter);
  FPostProcess.SetUniform('Normals', Normal, Sampler_NoFilter);
  FPostProcess.SetUniform('Depth', Depth, Sampler_Depth);
  FPostProcess.SetUniform('RandomTex', FRandomTex, Sampler_Linear_NoAnisotropy);
  FPostProcess.SetUniform('uHammerslaySpherePts', FHammersleySphere);
  FPostProcess.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);
end;

end.

