unit bLights;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, avBase, avRes, avTypes, avContnrs, avTess, mutils;

const
  SHADERS_FROMRES = False;
  SHADERS_DIR = 'D:\Projects\BackTerria\Src\shaders\!Out';

type

  { TPointLightMatrices }

  TPointLightMatrices = packed record
    viewProj: array [0..5] of TMat4;
    procedure Init(const APos: TVec3; const ARad: Single; const ADepthRange: TVec2);
  end;
  PPointLightMatrices = ^TPointLightMatrices;
  IPointLightMatricesArr = {$IfDef FPC}specialize{$EndIf} IArray<TPointLightMatrices>;
  TPointLightMatricesArr = {$IfDef FPC}specialize{$EndIf} TArray<TPointLightMatrices>;

  IGeometryRenderer = interface
    procedure ShadowPassGeometry(const APointLightMatrices: TPointLightMatrices);
    procedure DrawTransparentGeometry();
  end;

  TavLightRenderer = class;

  { TavLightSource }

  TavLightSource = class(TavObject)
  private
  protected
    function LightRenderer: TavLightRenderer; inline;
    function CanRegister(target: TavObject): boolean; override;
    procedure InvalidateLight;
  public
    constructor Create(AParent: TavObject); override;
    destructor Destroy; override;
  end;
  IavLightArr = {$IfDef FPC}specialize{$EndIf}IArray<TavLightSource>;
  TavLightArr = {$IfDef FPC}specialize{$EndIf}TArray<TavLightSource>;
  IavLightSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TavLightSource>;
  TavLightSet = {$IfDef FPC}specialize{$EndIf}THashSet<TavLightSource>;

  { TavPointLight }

  TavPointLight = class(TavLightSource)
  private
    FColor: TVec3;
    FPos: TVec3;
    FRadius: Single;
    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
  public
    property Pos   : TVec3  read FPos    write SetPos;
    property Radius: Single read FRadius write SetRadius;
    property Color : TVec3  read FColor  write SetColor;
  end;

  { TLightData }

  TLightData = packed record
    PosRange: TVec4;
    Color   : TVec3;
    class function Layout(): IDataLayout; static;
  end;
  ILightDataArr = {$IfDef FPC}specialize{$EndIf} IArray<TLightData>;
  TLightDataArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TLightData>;

  { TavLightRenderer }

  TavLightRenderer = class (TavMainRenderChild)
  private
    FLights: IavLightSet;
    FLightMatrices: IPointLightMatricesArr;
    FInvalidLights: IavLightSet;

    FLightData : ILightDataArr;
    FLightsBuffer    : TavSB;
    FLightsHeadBuffer: TavTexture3D;
    FLightLinkedList : TavUAV;

    //FRenderCluster_FBO: TavFrameBuffer;
    FRenderCluster_Prog: TavProgram;

    procedure ValidateLights;
    procedure BuildHeadBuffer;
  public
    procedure InvalidateShaders;

    function AddPointLight(): TavPointLight;

    function  LightsCount: Integer;
    procedure Reset;
    function  Next(out ALight: TavLightSource): Boolean;

    procedure Render(const ARenderer: IGeometryRenderer);

    function LightsHeadBuffer: TavTexture3D;
    function LightsLinkedList: TavUAV;
    function LightsList: TavSB;

    procedure AfterConstruction; override;
  end;

implementation

{ TPointLightMatrices }

procedure TPointLightMatrices.Init(const APos: TVec3; const ARad: Single; const ADepthRange: TVec2);
    function CalcPerspectiveMatrix: TMat4;
    const fFOV = 0.5 * Pi;
    const fAspect = 1.0;
    var w, h, Q: Single;
        DepthSize: Single;
        NearPlane, FarPlane: Single;
    begin
      FarPlane := ARad;
      NearPlane := FarPlane / 10000;
      h := (cos(fFOV/2)/sin(fFOV/2));
      w := fAspect * h;
      Q := 1.0/(NearPlane - FarPlane);
      DepthSize := ADepthRange.y - ADepthRange.x;

      ZeroClear(Result, SizeOf(Result));
      Result.f[0, 0] := w;
      Result.f[1, 1] := h;
      Result.f[2, 2] := ADepthRange.x - DepthSize * FarPlane * Q;
      Result.f[2, 3] := 1.0;
      Result.f[3, 2] := DepthSize * NearPlane * FarPlane * Q;
    end;
var mProj: TMat4;
    mView: TMat4;
begin
  mView := ZeroMat4;
  mProj := CalcPerspectiveMatrix;
  SetViewMatrix(mView, APos, APos + Vec( 100, 0, 0), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_X
  viewProj[0] := mView * mProj;
  SetViewMatrix(mView, APos, APos + Vec(-100, 0, 0), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_X
  viewProj[1] := mView * mProj;

  SetViewMatrix(mView, APos, APos + Vec(0,  100, 0), Vec(0, 0, 1)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Y
  viewProj[2] := mView * mProj;
  SetViewMatrix(mView, APos, APos + Vec(0, -100, 0), Vec(0, 0, 1)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Y
  viewProj[3] := mView * mProj;

  SetViewMatrix(mView, APos, APos + Vec(0, 0,  100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Z
  viewProj[4] := mView * mProj;
  SetViewMatrix(mView, APos, APos + Vec(0, 0, -100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
  viewProj[5] := mView * mProj;
end;

{ TLightData }

class function TLightData.Layout: IDataLayout;
begin
  Result := LB.Add('PosRange', ctFloat, 4)
              .Add('Color', ctFloat, 3)
              .Finish();
end;

{ TavPointLight }

procedure TavPointLight.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
  InvalidateLight;
end;

procedure TavPointLight.SetColor(const AValue: TVec3);
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  InvalidateLight;
end;

procedure TavPointLight.SetRadius(const AValue: Single);
begin
  if FRadius = AValue then Exit;
  FRadius := AValue;
  InvalidateLight;
end;

{ TavLightSource }

function TavLightSource.LightRenderer: TavLightRenderer;
begin
  Result := TavLightRenderer(Parent);
end;

function TavLightSource.CanRegister(target: TavObject): boolean;
begin
  Result := target is TavLightRenderer;
end;

procedure TavLightSource.InvalidateLight;
begin
  LightRenderer.FInvalidLights.Add(Self);
end;

constructor TavLightSource.Create(AParent: TavObject);
begin
  inherited Create(AParent);
  LightRenderer.FLights.Add(Self);
end;

destructor TavLightSource.Destroy;
begin
  inherited Destroy;
  LightRenderer.FLights.Delete(Self);
end;

{ TavLightRenderer }

procedure TavLightRenderer.ValidateLights;
var l: TavLightSource;
    pl: TavPointLight absolute l;
    ldata: TLightData;
    i: Integer;
begin
  if FInvalidLights.Count = 0 then Exit;

  FInvalidLights.Clear;
  FLightData.Clear;
  FLights.Reset;
  while FLights.Next(l) do
  begin
    if l is TavPointLight then
    begin
      ldata.PosRange := Vec(pl.Pos, pl.Radius);
      ldata.Color := pl.Color;
      FLightData.Add(ldata);
    end;
  end;

  if FLightMatrices = nil then
    FLightMatrices := TPointLightMatricesArr.Create();
  if  FLightMatrices.Count < FLightData.Count then
    FLightMatrices.SetSize(FLightData.Count);
  for i := 0 to FLightData.Count - 1 do
    PPointLightMatrices(FLightMatrices.PItem[i])^.Init(FLightData[i].PosRange.xyz, FLightData[i].PosRange.w, Main.Projection.DepthRange);
  FLightsBuffer.Invalidate;
end;

procedure TavLightRenderer.BuildHeadBuffer;
const NOLINK: Integer = Integer($FFFFFFFF);
begin
  ValidateLights;

  FRenderCluster_Prog.Select();
  FRenderCluster_Prog.SetComputeTex3D(0, FLightsHeadBuffer);
  FRenderCluster_Prog.SetComputeUAV(1, FLightLinkedList);

  try
    FRenderCluster_Prog.ClearComputeUAV(0, Vec(NOLINK,NOLINK,NOLINK,NOLINK));
    FRenderCluster_Prog.ResetUAVCounter(1);

    if FLightData.Count = 0 then Exit;

    FRenderCluster_Prog.SetUniform('depthRange', Main.Projection.DepthRange);
    FRenderCluster_Prog.SetUniform('lightCount', FLightData.Count*1.0);
    FRenderCluster_Prog.SetUniform('light_list', FLightsBuffer);
    FRenderCluster_Prog.SetUniform('headSize', FLightsHeadBuffer.Size*1.0);
    FRenderCluster_Prog.SetUniform('planesNearFar', Vec(Main.Projection.NearPlane, Main.Projection.FarPlane));

    FRenderCluster_Prog.DispatchDraw(Round(FLightsHeadBuffer.Size/Vec(8,8,8)));
  finally
    FRenderCluster_Prog.SetComputeTex3D(0, nil);
    FRenderCluster_Prog.SetComputeUAV(1, nil);
  end;
end;

procedure TavLightRenderer.InvalidateShaders;
begin
  FRenderCluster_Prog.Invalidate;
end;

function TavLightRenderer.AddPointLight: TavPointLight;
begin
  Result := TavPointLight.Create(Self);
end;

function TavLightRenderer.LightsCount: Integer;
begin
  Result := FLights.Count;
end;

procedure TavLightRenderer.Reset;
begin
  FLights.Reset;
end;

function TavLightRenderer.Next(out ALight: TavLightSource): Boolean;
begin
  Result := FLights.Next(ALight);
end;

procedure TavLightRenderer.Render(const ARenderer: IGeometryRenderer);
var
  i: Integer;
begin
  BuildHeadBuffer;
  for i := 0 to FLightData.Count - 1 do
    ARenderer.ShadowPassGeometry(PPointLightMatrices(FLightMatrices.PItem[i])^);
end;

function TavLightRenderer.LightsHeadBuffer: TavTexture3D;
begin
  Result := FLightsHeadBuffer;
end;

function TavLightRenderer.LightsLinkedList: TavUAV;
begin
  Result := FLightLinkedList;
end;

function TavLightRenderer.LightsList: TavSB;
begin
  Result := FLightsBuffer;
end;

procedure TavLightRenderer.AfterConstruction;
var cSize: TVec3i;
begin
  inherited AfterConstruction;
  cSize := Vec(32,32,32);
  cSize := cSize * 4;

  FLights := TavLightSet.Create();
  FInvalidLights := TavLightSet.Create();

  FLightsHeadBuffer := TavTexture3D.Create(Self);
  FLightsHeadBuffer.TargetFormat := TTextureFormat.R32;
  FLightsHeadBuffer.sRGB := False;
  FLightsHeadBuffer.AllocMem(cSize, False);

  FLightLinkedList := TavUAV.Create(Self);
  FLightLinkedList.SetSize(cSize.x*cSize.y*cSize.z*4, SizeOf(Integer)*2, False);

  FLightData := TLightDataArr.Create;
  FLightsBuffer := TavSB.Create(Self);
  FLightsBuffer.Vertices := FLightData as IVerticesData;

  FRenderCluster_Prog := TavProgram.Create(Self);
  FRenderCluster_Prog.Load('Lighting_render_clusters', SHADERS_FROMRES, SHADERS_DIR);

  //FRenderCluster_FBO := TavFrameBuffer.Create(Self);
  //FRenderCluster_FBO.SetUAV(0, FLightsHeadBuffer);
  //FRenderCluster_FBO.SetUAV(1, FLightsHeadBuffer);
end;

end.

