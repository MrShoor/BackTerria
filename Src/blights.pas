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
    class function Layout(): IDataLayout; static;
  end;
  PPointLightMatrices = ^TPointLightMatrices;
  IPointLightMatricesArr = {$IfDef FPC}specialize{$EndIf} IArray<TPointLightMatrices>;
  TPointLightMatricesArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TPointLightMatrices>;

  { TLightData }

  TLightData = packed record
    PosRange: TVec4;
    Color   : TVec3;
    ShadowSizeSliceRange : TVec3;
    class function Layout(): IDataLayout; static;
  end;
  ILightDataArr = {$IfDef FPC}specialize{$EndIf} IArray<TLightData>;
  TLightDataArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TLightData>;

  IShadowSlice = interface
    function SizeSliceRange: TVec3i;
  end;

  IGeometryRenderer = interface
    procedure ShadowPassGeometry(const ALight: TLightData; const APointLightMatrices: TPointLightMatrices);
    procedure DrawTransparentGeometry();
  end;

  TavLightRenderer = class;

  { TavLightSource }

  TavLightSource = class(TavObject)
  private
    FCastShadows: Boolean;
    FShadowSlice: IShadowSlice;
    procedure SetCastShadows(const AValue: Boolean);
  protected
    function LightRenderer: TavLightRenderer; inline;
    function CanRegister(target: TavObject): boolean; override;
    procedure InvalidateLight;
  public
    function ShadowSlice: IShadowSlice;

    property CastShadows: Boolean read FCastShadows write SetCastShadows;

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

  { TavShadowTextures }

  TavShadowTextures = class (TavTextureBase)
  private type
    TShadowHandle = class (TInterfacedObject, IShadowSlice)
    private
      FTexture: TavShadowTextures;
      FSizeSliceRange: TVec3i;
      function SizeSliceRange: TVec3i;
    public
      constructor Create(const ATexture: TavShadowTextures; const ASizeSliceRange: TVec3i);
      destructor Destroy; override;
    end;
  private
    FSlices   : array of Boolean;
    FSlicesFBO: array of TavFrameBuffer;

    FClusterSize: Integer;
    FTextureSize: Integer;

    procedure GrowAt(const ANewSize: Integer);

    function AllocSlice(): TVec3i;
    procedure FreeSlice(const ASliceIdx: Integer);
  protected
    function DoBuild: Boolean; override;
  public
    function AllocShadowSlice: IShadowSlice;
    function GetFBO(const ASlice: IShadowSlice): TavFrameBuffer; overload;
    function GetFBO(const ASizeSliceRange: TVec3i): TavFrameBuffer; overload;

    property TextureSize: Integer read FTextureSize;
    property ClusterSize: Integer read FClusterSize;

    procedure AfterConstruction; override;

    constructor Create(AOwner: TavObject; ATextureSize, AClusterSize: Integer); overload;
  end;

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

    FLightMatricesSB: TavSB;

    FCubes512: TavShadowTextures;

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
    function LightMatrices: TavSB;

    function Cubes512: TavShadowTextures;

    procedure AfterConstruction; override;
  end;

implementation

{ TavShadowTextures }

procedure TavShadowTextures.GrowAt(const ANewSize: Integer);
var oldSize, i: Integer;
begin
  oldSize := Length(FSlices);
  Assert(ANewSize >= oldSize);

  SetLength(FSlices, ANewSize);
  SetLength(FSlicesFBO, ANewSize);

  for i := 0 to oldSize - 1 do
    FSlicesFBO[i].Invalidate;

  for i := oldSize to Length(FSlices) - 1 do
  begin
    FSlices[i] := False;
    FSlicesFBO[i] := TavFrameBuffer.Create(Self);
    FSlicesFBO[i].SetDepth(Self, 0, i * FClusterSize, FClusterSize);
  end;
  Invalidate;
end;

function TavShadowTextures.AllocSlice: TVec3i;
var
  i: Integer;
begin
  for i := 0 to Length(FSlices) - 1 do
    if not FSlices[i] then
    begin
      Result.x := FTextureSize;
      Result.y := i * FClusterSize;
      Result.z := FClusterSize;
      FSlices[i] := True;
      Exit;
    end;
  GrowAt(Length(FSlices)*2);
end;

procedure TavShadowTextures.FreeSlice(const ASliceIdx: Integer);
begin
  FSlices[ASliceIdx div FClusterSize] := False;
end;

function TavShadowTextures.DoBuild: Boolean;
begin
  if FTexH = nil then FTexH := Main.Context.CreateTexture;
  FTexH.TargetFormat := TTextureFormat.D32f;
  FTexH.AllocMem(FTextureSize, FTextureSize, Length(FSlices)*FClusterSize, False, True);
  Result := True;
end;

function TavShadowTextures.AllocShadowSlice: IShadowSlice;
begin
  Result := TShadowHandle.Create(Self, AllocSlice());
end;

function TavShadowTextures.GetFBO(const ASlice: IShadowSlice): TavFrameBuffer;
begin
  Result := GetFBO(ASlice.SizeSliceRange);
end;

function TavShadowTextures.GetFBO(const ASizeSliceRange: TVec3i): TavFrameBuffer;
begin
  Result := FSlicesFBO[ASizeSliceRange.y div FClusterSize];
end;

procedure TavShadowTextures.AfterConstruction;
begin
  inherited AfterConstruction;
  GrowAt(1);
end;

constructor TavShadowTextures.Create(AOwner: TavObject; ATextureSize, AClusterSize: Integer);
begin
  Create(AOwner);
  FTextureSize := ATextureSize;
  FClusterSize := AClusterSize;
end;

{ TavShadowTextures.TShadowHandle }

function TavShadowTextures.TShadowHandle.SizeSliceRange: TVec3i;
begin
  Result := FSizeSliceRange;
end;

constructor TavShadowTextures.TShadowHandle.Create(const ATexture: TavShadowTextures; const ASizeSliceRange: TVec3i);
begin
  FTexture := ATexture;
  FSizeSliceRange := ASizeSliceRange;
end;

destructor TavShadowTextures.TShadowHandle.Destroy;
begin
  FTexture.FreeSlice(FSizeSliceRange.y);
  inherited Destroy;
end;

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
      NearPlane := FarPlane / 1000;
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

  SetViewMatrix(mView, APos, APos + Vec(0,  100, 0), Vec(0, 0, -1)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Y
  viewProj[2] := mView * mProj;
  SetViewMatrix(mView, APos, APos + Vec(0, -100, 0), Vec(0, 0, 1)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Y
  viewProj[3] := mView * mProj;

  SetViewMatrix(mView, APos, APos + Vec(0, 0,  100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Z
  viewProj[4] := mView * mProj;
  SetViewMatrix(mView, APos, APos + Vec(0, 0, -100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
  viewProj[5] := mView * mProj;
end;

class function TPointLightMatrices.Layout: IDataLayout;
begin
  Result := LB.Add('MatRow0', ctFloat, 4)
              .Add('MatRow1', ctFloat, 4)
              .Add('MatRow2', ctFloat, 4)
              .Add('MatRow3', ctFloat, 4)
              .Finish();
end;

{ TLightData }

class function TLightData.Layout: IDataLayout;
begin
  Result := LB.Add('PosRange', ctFloat, 4)
              .Add('Color', ctFloat, 3)
              .Add('ShadowSizeSliceRange', ctFloat, 3)
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

procedure TavLightSource.SetCastShadows(const AValue: Boolean);
begin
  if FCastShadows = AValue then Exit;
  FCastShadows := AValue;
  if FCastShadows then
    FShadowSlice := LightRenderer.Cubes512.AllocShadowSlice
  else
    FShadowSlice := nil;
  InvalidateLight;
end;

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

function TavLightSource.ShadowSlice: IShadowSlice;
begin
  Result := FShadowSlice;
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
      if l.CastShadows then
        ldata.ShadowSizeSliceRange := l.ShadowSlice.SizeSliceRange
      else
        ldata.ShadowSizeSliceRange := Vec(-1,-1,-1);
      FLightData.Add(ldata);
    end;
  end;

  if  FLightMatrices.Count < FLightData.Count then
    FLightMatrices.SetSize(FLightData.Count);
  for i := 0 to FLightData.Count - 1 do
    PPointLightMatrices(FLightMatrices.PItem[i])^.Init(FLightData[i].PosRange.xyz, FLightData[i].PosRange.w, Main.Projection.DepthRange);
  FLightsBuffer.Invalidate;
  FLightMatricesSB.Invalidate;
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
  ld: TLightData;
  fbo: TavFrameBuffer;
begin
  BuildHeadBuffer;
  for i := 0 to FLightData.Count - 1 do
  begin
    ld := FLightData[i];
    if ld.ShadowSizeSliceRange.y >= 0 then
    begin
      fbo := FCubes512.GetFBO(Trunc(ld.ShadowSizeSliceRange));
      fbo.FrameRect := RectI(0, 0, FCubes512.TextureSize, FCubes512.TextureSize);
      fbo.Select();
      fbo.ClearDS(Main.Projection.DepthRange.y);
      ARenderer.ShadowPassGeometry( FLightData[i], PPointLightMatrices(FLightMatrices.PItem[i])^);
    end;
  end;
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

function TavLightRenderer.LightMatrices: TavSB;
begin
  Result := FLightMatricesSB;
end;

function TavLightRenderer.Cubes512: TavShadowTextures;
begin
  Result := FCubes512;
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

  FCubes512 := TavShadowTextures.Create(Self, 512, 6);

  FLightMatrices := TPointLightMatricesArr.Create();
  FLightMatricesSB := TavSB.Create(Self);
  FLightMatricesSB.Vertices := FLightMatrices as IVerticesData;
  //FLightMatrices.Vertices :=

  //FRenderCluster_FBO := TavFrameBuffer.Create(Self);
  //FRenderCluster_FBO.SetUAV(0, FLightsHeadBuffer);
  //FRenderCluster_FBO.SetUAV(1, FLightsHeadBuffer);
end;

end.

