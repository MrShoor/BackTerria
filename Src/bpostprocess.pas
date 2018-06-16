unit bPostProcess;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, avRes, avTypes, mutils;

const
  SHADERS_FROMRES = False;
  SHADERS_DIR = 'D:\Projects\BackTerria\Src\shaders\!Out';

type

  { TavPostProcess }

  TavPostProcess = class (TavMainRenderChild)
  private
    FResultFBO: TavFrameBuffer;
    FPostProcess: TavProgram;
    FRandomTex: TavTexture;
    function GetResult0: TavTextureBase;
  protected
    procedure AfterRegister; override;
  public
    procedure InvalidateShaders;

    procedure DoPostProcess(AColor, ANormal, ADepth: TavTextureBase);

    property Result0: TavTextureBase read GetResult0;
    property ResultFBO: TavFrameBuffer read FResultFBO;
  end;

implementation

uses
  avTexLoader;

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
      pv^ := Vec(Random(), Random(), Random(), 0);
      Inc(pv);
    end;
  end;

begin
  inherited AfterRegister;
  FResultFBO := Create_FrameBuffer(Self, [TTextureFormat.RGBA], [true]);

  FPostProcess := TavProgram.Create(Self);
  FPostProcess.Load('PostProcess1', SHADERS_FROMRES, SHADERS_DIR);

  FRandomTex := TavTexture.Create(Self);
  FRandomTex.TargetFormat := TTextureFormat.RGBA32f;
  FRandomTex.TexData := GetRandomTextureData;
end;

procedure TavPostProcess.InvalidateShaders;
begin
  FPostProcess.Invalidate;
end;

procedure TavPostProcess.DoPostProcess(AColor, ANormal, ADepth: TavTextureBase);
begin
  FResultFBO.FrameRect := Main.States.Viewport;
  FResultFBO.Select;

  FPostProcess.Select();
  FPostProcess.SetUniform('Color', AColor, Sampler_NoFilter);
  FPostProcess.SetUniform('Normals', ANormal, Sampler_NoFilter);
  FPostProcess.SetUniform('Depth', ADepth, Sampler_Depth);
  FPostProcess.SetUniform('RandomTex', FRandomTex, Sampler_Linear);
  FPostProcess.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);
end;

end.

