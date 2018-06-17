unit bLights;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, avBase, avRes, avTypes, avContnrs, avTess, mutils;

{$I bshaders.inc}

type
  TavLightSource = class;
  IavLightAdapter = interface
    procedure _DisconnectAdapter;
  end;

  { TPointLightMatrices }

  TPointLightMatrices = packed record
    viewProj: array [0..5] of TMat4;
    procedure Init(const APos: TVec3; const ARad: Single; const ADepthRange: TVec2);
  end;
  PPointLightMatrices = ^TPointLightMatrices;

  { TShadowMatrix }

  TShadowMatrix = packed record
    viewProj: TMat4;
    class function Layout(): IDataLayout; static;
  end;
  PShadowMatrix = ^TShadowMatrix;
  IShadowMatrixArr = {$IfDef FPC}specialize{$EndIf} IArray<TShadowMatrix>;
  TShadowMatrixArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TShadowMatrix>;

  { TLightData }

  TLightData = packed record
    PosRange: TVec4;
    Color   : TVec3;
    MatrixOffset: Cardinal;
    ShadowSizeSliceRange : TVec3i;
    class function Layout(): IDataLayout; static;
  end;
  PLightData = ^TLightData;
  ILightDataArr = {$IfDef FPC}specialize{$EndIf} IArray<TLightData>;
  TLightDataArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TLightData>;

  IShadowSlice = interface
    function SizeSliceRange: TVec3i;
  end;

  IMatricesHandle = interface
    procedure Invalidate;
    function  Mat  : PMat4;
    function  Count: Integer;
  end;

  IGeometryRenderer = interface
    procedure ShadowPassGeometry(const ALight: TavLightSource; const ALightData: TLightData);
    procedure DrawTransparentGeometry();
  end;

  TavLightRenderer = class;

  { TavLightSource }

  TavLightSource = class(TavObject)
  protected
    FCastShadows: Boolean;
    FLightIndex : Integer;

    FShadowSlice: IShadowSlice;
    FMatrices: IShadowMatrixArr;
    FMatricesHandle: ISBManagedHandle;

    FAdapter: Pointer;

    procedure SetCastShadows(const AValue: Boolean);

    procedure SetAdapter(const AAdapter: IavLightAdapter);
  protected
    function LightRenderer: TavLightRenderer; inline;
    function CanRegister(target: TavObject): boolean; override;
    procedure InvalidateLight;
    procedure ValidateLight(const AMain: TavMainRender); virtual;
  public
    function ShadowSlice: IShadowSlice;

    property CastShadows: Boolean read FCastShadows write SetCastShadows;
    function Matrices: PMat4;
    function MatricesCount: Integer;

    constructor Create(AParent: TavObject); override;
    destructor Destroy; override;
  end;
  IavLightArr = {$IfDef FPC}specialize{$EndIf}IArray<TavLightSource>;
  TavLightArr = {$IfDef FPC}specialize{$EndIf}TArray<TavLightSource>;
  IavLightSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TavLightSource>;
  TavLightSet = {$IfDef FPC}specialize{$EndIf}THashSet<TavLightSource>;

  { IavLightSource }

  IavLightSource = interface (IavLightAdapter)
    function GetCastShadows: Boolean;
    procedure SetCastShadows(const AValue: Boolean);

    function ShadowSlice: IShadowSlice;

    property CastShadows: Boolean read GetCastShadows write SetCastShadows;
    function Matrices: PMat4;
    function MatricesCount: Integer;
  end;

  { IavPointLight }

  IavPointLight = interface (IavLightSource)
    function GetColor: TVec3;
    function GetPos: TVec3;
    function GetRadius: Single;
    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);

    property Pos   : TVec3  read GetPos    write SetPos;
    property Radius: Single read GetRadius write SetRadius;
    property Color : TVec3  read GetColor  write SetColor;
  end;

  { TavPointLight }

  TavPointLight = class(TavLightSource)
  private
    FColor: TVec3;
    FPos: TVec3;
    FRadius: Single;

    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
  protected
    procedure ValidateLight(const AMain: TavMainRender); override;
  public
    property Pos   : TVec3  read FPos    write SetPos;
    property Radius: Single read FRadius write SetRadius;
    property Color : TVec3  read FColor  write SetColor;

    procedure AfterConstruction; override;
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
    FFBOAll : TavFrameBuffer;

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
    function GetFBOAll: TavFrameBuffer;

    property TextureSize: Integer read FTextureSize;
    property ClusterSize: Integer read FClusterSize;

    procedure AfterConstruction; override;

    constructor Create(AOwner: TavObject; ATextureSize, AClusterSize: Integer); overload;
  end;

  { TavLightRenderer }

  TavLightRenderer = class (TavMainRenderChild)
  private
    FLights       : IavLightArr;
    FLightsData   : ILightDataArr;

    FInvalidLights: IavLightSet;

    FLightsBuffer    : TavSB;
    FLightsHeadBuffer: TavTexture3D;
    FLightLinkedList : TavUAV;

    FLightMatricesSB: TavSBManaged;

    FCubes512: TavShadowTextures;

    FRenderCluster_Prog: TavProgram;

    procedure ValidateLights;
    procedure BuildHeadBuffer;
  public
    procedure InvalidateShaders;

    function AddPointLight(): IavPointLight;

    function  LightsCount: Integer;
    function  GetLight(AIndex: Integer): TavLightSource;

    procedure Render(const ARenderer: IGeometryRenderer);

    function LightsHeadBuffer: TavTexture3D;
    function LightsLinkedList: TavUAV;
    function LightsList: TavSB;
    function LightMatrices: TavStructuredBase;

    function Cubes512: TavShadowTextures;

    procedure AfterConstruction; override;
  end;

implementation

const
  cComputeDispatchSize = 4;
  cAverageLightsPerCluster = 4;

type

  { TavLightSourceAdapter }

  TavLightSourceAdapter = class (TInterfacedObject, IavLightSource)
  private
    function GetCastShadows: Boolean;
    procedure SetCastShadows(const AValue: Boolean);
    function ShadowSlice: IShadowSlice;
    function Matrices: PMat4;
    function MatricesCount: Integer;
  protected
    procedure _DisconnectAdapter; virtual; abstract;
    function GetLightSource: TavLightSource; virtual; abstract;
  public
    destructor Destroy; override;
  end;

  { TavPointLightAdapter }

  TavPointLightAdapter = class (TavLightSourceAdapter, IavPointLight)
  private
    FLight: TavPointLight;
    function GetColor: TVec3;
    function GetPos: TVec3;
    function GetRadius: Single;
    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
  protected
    procedure _DisconnectAdapter; override;
    function GetLightSource: TavLightSource; override;
  public
    constructor Create(const ALight: TavPointLight);
  end;

{ TavPointLightAdapter }

function TavPointLightAdapter.GetColor: TVec3;
begin
  if FLight = nil then Exit(Vec(0,0,0));
  Result := FLight.Color;
end;

function TavPointLightAdapter.GetPos: TVec3;
begin
  if FLight = nil then Exit(Vec(0,0,0));
  Result := FLight.Pos;
end;

function TavPointLightAdapter.GetRadius: Single;
begin
  if FLight = nil then Exit(0);
  Result := FLight.Radius;
end;

procedure TavPointLightAdapter.SetColor(const AValue: TVec3);
begin
  if FLight = nil then Exit();
  FLight.Color := AValue;
end;

procedure TavPointLightAdapter.SetPos(const AValue: TVec3);
begin
  if FLight = nil then Exit();
  FLight.Pos := AValue;
end;

procedure TavPointLightAdapter.SetRadius(const AValue: Single);
begin
  if FLight = nil then Exit();
  FLight.Radius := AValue;
end;

procedure TavPointLightAdapter._DisconnectAdapter;
begin
  FLight := nil;
end;

function TavPointLightAdapter.GetLightSource: TavLightSource;
begin
  Result := FLight;
end;

constructor TavPointLightAdapter.Create(const ALight: TavPointLight);
var intf: IavPointLight;
begin
  intf := Self;
  FLight := ALight;
  FLight.SetAdapter(intf);
end;

{ TavLightSourceAdapter }

function TavLightSourceAdapter.GetCastShadows: Boolean;
begin
  if GetLightSource = nil then Exit(False);
  Result := GetLightSource.CastShadows;
end;

procedure TavLightSourceAdapter.SetCastShadows(const AValue: Boolean);
begin
  if GetLightSource = nil then Exit();
  GetLightSource.CastShadows := AValue;
end;

function TavLightSourceAdapter.ShadowSlice: IShadowSlice;
begin
  if GetLightSource = nil then Exit(nil);
  Result := GetLightSource.ShadowSlice;
end;

function TavLightSourceAdapter.Matrices: PMat4;
begin
  if GetLightSource = nil then Exit(nil);
  Result := GetLightSource.Matrices;
end;

function TavLightSourceAdapter.MatricesCount: Integer;
begin
  if GetLightSource = nil then Exit(0);
  Result := GetLightSource.MatricesCount;
end;

destructor TavLightSourceAdapter.Destroy;
var ls: TavLightSource;
begin
  ls := GetLightSource;
  if Assigned(ls) then
  begin
    ls.SetAdapter(nil);
    FreeAndNil(ls);
  end;
  inherited Destroy;
end;

{ TShadowMatrix }

class function TShadowMatrix.Layout: IDataLayout;
begin
  Result := LB.Add('MatRow0', ctFloat, 4)
              .Add('MatRow1', ctFloat, 4)
              .Add('MatRow2', ctFloat, 4)
              .Add('MatRow3', ctFloat, 4)
              .Finish();
end;

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

  if oldSize < ANewSize then
  begin
    FreeAndNil(FFBOAll);
    FFBOAll := TavFrameBuffer.Create(Self);
    FFBOAll.SetDepth(Self, 0, 0, ANewSize*6);
  end;

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
  Result := AllocSlice();
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

function TavShadowTextures.GetFBOAll: TavFrameBuffer;
begin
  Result := FFBOAll;
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

{ TLightData }

class function TLightData.Layout: IDataLayout;
begin
  Result := LB.Add('PosRange', ctFloat, 4)
              .Add('Color', ctFloat, 3)
              .Add('MatrixOffset', ctUInt, 1)
              .Add('ShadowSizeSliceRange', ctInt, 3)
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

procedure TavPointLight.ValidateLight(const AMain: TavMainRender);
var pld: PLightData;
begin
  FMatricesHandle := nil;
  pld := LightRenderer.FLightsData.PItem[FLightIndex];
  pld^.PosRange := Vec(FPos, FRadius);
  pld^.Color := FColor;
  if FCastShadows then
  begin
    PPointLightMatrices(FMatrices.PItem[0])^.Init(Pos, Radius, AMain.Projection.DepthRange);
    FMatricesHandle := LightRenderer.FLightMatricesSB.Add(FMatrices as IVerticesData);
    pld^.MatrixOffset := FMatricesHandle.Offset;
    pld^.ShadowSizeSliceRange := FShadowSlice.SizeSliceRange;
  end
  else
  begin
    pld^.MatrixOffset := 0;
    pld^.ShadowSizeSliceRange := Vec(-1,-1,-1);
  end;
end;

procedure TavPointLight.AfterConstruction;
begin
  inherited AfterConstruction;
  FMatrices := TShadowMatrixArr.Create();
  FMatrices.SetSize(6);
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

procedure TavLightSource.SetAdapter(const AAdapter: IavLightAdapter);
begin
  FAdapter := Pointer(AAdapter);
end;

function TavLightSource.LightRenderer: TavLightRenderer;
begin
  Result := TavLightRenderer(Parent);
end;

function TavLightSource.Matrices: PMat4;
begin
  Result := PMat4(FMatrices.PItem[0]);
end;

function TavLightSource.MatricesCount: Integer;
begin
  Result := FMatrices.Count;
end;

function TavLightSource.CanRegister(target: TavObject): boolean;
begin
  Result := target is TavLightRenderer;
end;

procedure TavLightSource.InvalidateLight;
begin
  LightRenderer.FInvalidLights.Add(Self);
end;

procedure TavLightSource.ValidateLight(const AMain: TavMainRender);
begin

end;

function TavLightSource.ShadowSlice: IShadowSlice;
begin
  Result := FShadowSlice;
end;

constructor TavLightSource.Create(AParent: TavObject);
var ld: TLightData;
begin
  inherited Create(AParent);
  FLightIndex := LightRenderer.FLights.Add(Self);
  LightRenderer.FLightsData.Add(ld);
  LightRenderer.FLightsBuffer.Invalidate;
end;

destructor TavLightSource.Destroy;
var l: TavLightSource;
begin
  inherited Destroy;
  if Assigned(FAdapter) then IavLightAdapter(FAdapter)._DisconnectAdapter;

  LightRenderer.FLights.DeleteWithSwap(FLightIndex);
  LightRenderer.FLightsData.DeleteWithSwap(FLightIndex);
  l := LightRenderer.FLights[FLightIndex];
  l.FLightIndex := FLightIndex;
end;

{ TavLightRenderer }

procedure TavLightRenderer.ValidateLights;
var l: TavLightSource;
begin
  if FInvalidLights.Count = 0 then Exit;

  FInvalidLights.Reset;
  while FInvalidLights.Next(l) do
    l.ValidateLight(Main);
  FInvalidLights.Clear;

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

    if not FLightsData.Count > 0 then Exit;

    FRenderCluster_Prog.SetUniform('depthRange', Main.Projection.DepthRange);
    FRenderCluster_Prog.SetUniform('lightCount', FLightsData.Count*1.0);
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

function TavLightRenderer.AddPointLight: IavPointLight;
begin
  Result := TavPointLightAdapter.Create(TavPointLight.Create(Self));
end;

function TavLightRenderer.LightsCount: Integer;
begin
  Result := FLights.Count;
end;

function TavLightRenderer.GetLight(AIndex: Integer): TavLightSource;
begin
  Result := FLights[AIndex];
end;

procedure TavLightRenderer.Render(const ARenderer: IGeometryRenderer);
var
  i: Integer;
  ld: TLightData;
  fbo: TavFrameBuffer;
begin
  BuildHeadBuffer;

//  fbo := FCubes512.GetFBOAll();
//  fbo.FrameRect := RectI(0, 0, FCubes512.TextureSize, FCubes512.TextureSize);
//  fbo.Select();
//  fbo.ClearDS(Main.Projection.DepthRange.y);

  for i := 0 to FLights.Count - 1 do
  begin
    ld := FLightsData[i];
    if ld.ShadowSizeSliceRange.y >= 0 then
    begin
      fbo := FCubes512.GetFBO(ld.ShadowSizeSliceRange);
      fbo.FrameRect := RectI(0, 0, FCubes512.TextureSize, FCubes512.TextureSize);
      fbo.Select();
      fbo.ClearDS(Main.Projection.DepthRange.y);
      ARenderer.ShadowPassGeometry( FLights[i], ld);
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

function TavLightRenderer.LightMatrices: TavStructuredBase;
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
  cSize := Vec(4,4,4);
  cSize := cSize * cComputeDispatchSize;

  FLights := TavLightArr.Create();
  FInvalidLights := TavLightSet.Create();

  FLightsHeadBuffer := TavTexture3D.Create(Self);
  FLightsHeadBuffer.TargetFormat := TTextureFormat.R32;
  FLightsHeadBuffer.sRGB := False;
  FLightsHeadBuffer.AllocMem(cSize, False);

  FLightLinkedList := TavUAV.Create(Self);
  FLightLinkedList.SetSize(cSize.x*cSize.y*cSize.z*cAverageLightsPerCluster, SizeOf(Integer)*2, False);

  FLightsData := TLightDataArr.Create;
  FLightsBuffer := TavSB.Create(Self);
  FLightsBuffer.Vertices := FLightsData as IVerticesData;

  FRenderCluster_Prog := TavProgram.Create(Self);
  FRenderCluster_Prog.Load('Lighting_render_clusters', SHADERS_FROMRES, SHADERS_DIR);

  FCubes512 := TavShadowTextures.Create(Self, 512, 6);

  FLightMatricesSB := TavSBManaged.Create(Self);
end;

end.

