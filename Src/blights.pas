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

  { TShadowMatrix }

  TShadowMatrix = packed record
    viewProj: TMat4;
    view    : TMat4;
    proj    : TMat4;
    projInv : TMat4;
    class function Layout(): IDataLayout; static;
  end;
  PShadowMatrix = ^TShadowMatrix;
  IShadowMatrixArr = {$IfDef FPC}specialize{$EndIf} IArray<TShadowMatrix>;
  TShadowMatrixArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TShadowMatrix>;

  { TPointLightMatrices }

  TPointLightMatrices = packed record
    sm: array [0..5] of TShadowMatrix;
    procedure Init(const APos: TVec3; const ARad: Single; const ADepthRange: TVec2);
  end;
  PPointLightMatrices = ^TPointLightMatrices;

  { TLightData }

  TLightData = packed record
    PosRange : TVec4;
    LightSize: Single;
    Color    : TVec3;
    Dir      : TVec3;
    Angles   : TVec2;
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

  IGeometryRenderer = interface
    procedure ShadowPassGeometry(const ALight: TavLightSource; const ALightData: TLightData);
    procedure DrawTransparentGeometry();
  end;

  TavLightRenderer = class;

  TShadowsType = (stNone, st64, st128, st256, st512, st1024, st2048);
const
  cShadowsTypeSize: array [TShadowsType] of Integer = (0, 64, 128, 256, 512, 1024, 2048);

type

  { TavLightSource }

  TavLightSource = class(TavObject)
  protected
    FCastShadows: TShadowsType;
    FLightIndex : Integer;

    FShadowSlice: IShadowSlice;
    FMatrices: IShadowMatrixArr;
    FMatricesHandle: ISBManagedHandle;

    FAdapter: Pointer;

    function AllocShadowSlices: IShadowSlice; virtual; abstract;
    procedure SetCastShadows(const AValue: TShadowsType); virtual;

    procedure SetAdapter(const AAdapter: IavLightAdapter);
  protected
    function LightRenderer: TavLightRenderer; inline;
    function CanRegister(target: TavObject): boolean; override;
    procedure InvalidateLight;
    procedure ValidateLight(const AMain: TavMainRender); virtual;
  public
    function InFrustum(const AFrustum: TFrustum): Boolean; virtual;

    function ShadowSlice: IShadowSlice;

    property CastShadows: TShadowsType read FCastShadows write SetCastShadows;
    function Matrices: PShadowMatrix;
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
    function GetCastShadows: TShadowsType;
    procedure SetCastShadows(const AValue: TShadowsType);

    function ShadowSlice: IShadowSlice;

    property CastShadows: TShadowsType read GetCastShadows write SetCastShadows;
    function Matrices: PShadowMatrix;
    function MatricesCount: Integer;
  end;

  { IavPointLight }

  IavPointLight = interface (IavLightSource)
    function GetColor: TVec3;
    function GetPos: TVec3;
    function GetRadius: Single;
    function GetSize: Single;
    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
    procedure SetSize(const AValue: Single);

    property Pos   : TVec3  read GetPos    write SetPos;
    property Radius: Single read GetRadius write SetRadius;
    property Size  : Single read GetSize   write SetSize;
    property Color : TVec3  read GetColor  write SetColor;
  end;

  { IavSpotLight }

  IavSpotLight = interface (IavLightSource)
    function GetAngles: TVec2;
    function GetColor: TVec3;
    function GetDir: TVec3;
    function GetPos: TVec3;
    function GetRadius: Single;
    function GetSize: Single;
    procedure SetAngles(const AValue: TVec2);
    procedure SetColor(const AValue: TVec3);
    procedure SetDir(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
    procedure SetSize(const AValue: Single);

    property Pos: TVec3 read GetPos write SetPos;
    property Dir: TVec3 read GetDir write SetDir;
    property Radius: Single read GetRadius write SetRadius;
    property Size  : Single read GetSize   write SetSize;
    property Angles: TVec2 read GetAngles write SetAngles;
    property Color : TVec3 read GetColor write SetColor;
  end;

  { IavDirectionalLight }

  IavDirectionalLight = interface (IavLightSource)
    function GetColor: TVec3;
    function GetDir: TVec3;
    function GetPos: TVec3;
    function GetRadius: Single;
    procedure SetColor(const AValue: TVec3);
    procedure SetDir(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);

    property Pos: TVec3 read GetPos write SetPos;
    property Dir: TVec3 read GetDir write SetDir;
    property Radius: Single read GetRadius write SetRadius;
    property Color : TVec3 read GetColor write SetColor;
  end;

  { TavPointLight }

  TavPointLight = class(TavLightSource)
  private
    FColor: TVec3;
    FPos: TVec3;
    FRadius: Single;
    FSize: Single;

    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
    procedure SetSize(const AValue: Single);
  protected
    function AllocShadowSlices: IShadowSlice; override;
    procedure ValidateLight(const AMain: TavMainRender); override;
  public
    function InFrustum(const AFrustum: TFrustum): Boolean; override;

    property Pos   : TVec3  read FPos    write SetPos;
    property Radius: Single read FRadius write SetRadius;
    property Size  : Single read FSize   write SetSize;
    property Color : TVec3  read FColor  write SetColor;

    procedure AfterConstruction; override;
  end;

  { TavSpotLight }

  TavSpotLight = class(TavLightSource)
  private
    FAngles: TVec2;
    FColor: TVec3;
    FDir: TVec3;
    FPos: TVec3;
    FRadius: Single;
    FSize: Single;
    procedure SetAngles(AValue: TVec2);
    procedure SetColor(const AValue: TVec3);
    procedure SetDir(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
    procedure SetSize(const AValue: Single);
  protected
    function AllocShadowSlices: IShadowSlice; override;
    procedure ValidateLight(const AMain: TavMainRender); override;
  public
    function InFrustum(const AFrustum: TFrustum): Boolean; override;

    property Pos: TVec3 read FPos write SetPos;
    property Dir: TVec3 read FDir write SetDir;
    property Radius: Single read FRadius write SetRadius;
    property Size  : Single read FSize write SetSize;
    property Angles: TVec2 read FAngles write SetAngles;
    property Color : TVec3 read FColor write SetColor;

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
    FWithMips   : Boolean;

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

    constructor Create(AOwner: TavObject; ATextureSize, AClusterSize: Integer; AWithMips: Boolean); overload;
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

    FCubes: array [TShadowsType] of TavShadowTextures;
    FSpots: array [TShadowsType] of TavShadowTextures;

    FRenderCluster_Prog: TavProgram;

    procedure ValidateLights;
    procedure BuildHeadBuffer;
  public
    procedure InvalidateShaders;

    function AddPointLight(): IavPointLight;
    function AddDirectionalLight(): IavDirectionalLight;
    function AddSpotLight(): IavSpotLight;

    function  LightsCount: Integer;
    function  GetLight(AIndex: Integer): TavLightSource;

    procedure Render(const ARenderer: IGeometryRenderer);

    function LightsHeadBuffer: TavTexture3D;
    function LightsLinkedList: TavUAV;
    function LightsList: TavSB;
    function LightMatrices: TavStructuredBase;

    function Cubes(const AType: TShadowsType): TavShadowTextures;
    function Spots(const AType: TShadowsType): TavShadowTextures;

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
    function GetCastShadows: TShadowsType;
    procedure SetCastShadows(const AValue: TShadowsType);
    function ShadowSlice: IShadowSlice;
    function Matrices: PShadowMatrix;
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
    function GetSize: Single;
    procedure SetColor(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
    procedure SetSize(const AValue: Single);
  protected
    procedure _DisconnectAdapter; override;
    function GetLightSource: TavLightSource; override;
  public
    constructor Create(const ALight: TavPointLight);
  end;

  { TavSpotLightAdapter }

  TavSpotLightAdapter = class (TavLightSourceAdapter, IavSpotLight)
  private
    FLight: TavSpotLight;
    function GetAngles: TVec2;
    function GetColor: TVec3;
    function GetDir: TVec3;
    function GetPos: TVec3;
    function GetRadius: Single;
    function GetSize: Single;
    procedure SetAngles(const AValue: TVec2);
    procedure SetColor(const AValue: TVec3);
    procedure SetDir(const AValue: TVec3);
    procedure SetPos(const AValue: TVec3);
    procedure SetRadius(const AValue: Single);
    procedure SetSize(const AValue: Single);
  protected
    procedure _DisconnectAdapter; override;
    function GetLightSource: TavLightSource; override;
  public
    constructor Create(const ALight: TavSpotLight);
  end;

function LightIntersectFrusum(const ALightPos, ALightDir: TVec3; ALightRange, ALightCosHalfAngle: Single; const AFrustum: TFrustum): Boolean;

  function GetSplitPlane(const APt: TVec3) : TPlane;

    function PointLineProjection(const pt, ro, rd_n: TVec3) : TVec3;
    begin
        Result := ro + rd_n * dot(pt-ro, rd_n);
    end;

  var ptDir: TVec3;
      ptDirLen: Single;
      dot_ptDir_lDir: Single;
      pp: TVec3;
      a, b, b2, tn: Single;
      p1, p2: TVec3;
  begin
      Result := Plane(0,0,0,0);
      ptDir := APt - ALightPos;
      ptDirLen := Len(ptDir);
      dot_ptDir_lDir := Dot(ptDir, ALightDir);
      if ( dot_ptDir_lDir >= ALightCosHalfAngle*ptDirLen ) then //point case
      begin
          Result.Norm := normalize(APt - ALightPos);
          Result.D := -dot(Result.Norm, ALightPos + Result.Norm*ALightRange);
      end
      else //cone side case
      begin
          pp := PointLineProjection(APt, ALightPos, ALightDir);
          a := Len(pp - ALightPos);
          tn := sqrt( Clamp(1.0 - sqr(ALightCosHalfAngle), 0.0, 1.0) ) / ALightCosHalfAngle;
          b := a * tn;
          p1 := pp + normalize(APt - pp)*b;
          b2 := b * tn;
          p2 := pp + ALightDir * b2;
          Result.Norm := normalize(p1 - p2);
          Result.D := -dot(Result.Norm, ALightPos);
      end;
  end;

var i, j: Integer;
    pl: TPlane;
begin
  for i := 0 to 5 do
      if (dot(AFrustum.planes[i].Norm, ALightPos) + AFrustum.planes[i].D > ALightRange) then
        Exit(False);
  for i := 0 to 7 do
  begin
    pl := GetSplitPlane(AFrustum.pts[i]);
    j := 0;
    while j < 8 do
    begin
      if (dot(AFrustum.pts[j], pl.Norm)+pl.D < 0) then
        Break;
      Inc(j);
    end;
    if j = 8 then Exit(False);
  end;
  Result := True;
end;

{ TavSpotLightAdapter }

function TavSpotLightAdapter.GetAngles: TVec2;
begin
  if FLight = nil then Exit(Vec(0,0));
  Result := FLight.Angles;
end;

function TavSpotLightAdapter.GetColor: TVec3;
begin
  if FLight = nil then Exit(Vec(0,0,0));
  Result := FLight.Color;
end;

function TavSpotLightAdapter.GetDir: TVec3;
begin
  if FLight = nil then Exit(Vec(0,0,0));
  Result := FLight.Dir;
end;

function TavSpotLightAdapter.GetPos: TVec3;
begin
  if FLight = nil then Exit(Vec(0,0,0));
  Result := FLight.Pos;
end;

function TavSpotLightAdapter.GetRadius: Single;
begin
  if FLight = nil then Exit(0);
  Result := FLight.Radius;
end;

function TavSpotLightAdapter.GetSize: Single;
begin
  if FLight = nil then Exit(0);
  Result := FLight.Size;
end;

procedure TavSpotLightAdapter.SetAngles(const AValue: TVec2);
begin
  if FLight = nil then Exit;
  FLight.Angles := AValue;
end;

procedure TavSpotLightAdapter.SetColor(const AValue: TVec3);
begin
  if FLight = nil then Exit;
  FLight.Color := AValue;
end;

procedure TavSpotLightAdapter.SetDir(const AValue: TVec3);
begin
  if FLight = nil then Exit;
  FLight.Dir := AValue;
end;

procedure TavSpotLightAdapter.SetPos(const AValue: TVec3);
begin
  if FLight = nil then Exit;
  FLight.Pos := AValue;
end;

procedure TavSpotLightAdapter.SetRadius(const AValue: Single);
begin
  if FLight = nil then Exit;
  FLight.Radius := AValue;
end;

procedure TavSpotLightAdapter.SetSize(const AValue: Single);
begin
  if FLight = nil then Exit;
  FLight.Size := AValue;
end;

procedure TavSpotLightAdapter._DisconnectAdapter;
begin
  FLight := nil;
end;

function TavSpotLightAdapter.GetLightSource: TavLightSource;
begin
  Result := FLight;
end;

constructor TavSpotLightAdapter.Create(const ALight: TavSpotLight);
var intf: IavSpotLight;
begin
  intf := Self;
  FLight := ALight;
  FLight.SetAdapter(intf);
end;

{ TavSpotLight }

procedure TavSpotLight.SetAngles(AValue: TVec2);
begin
  AValue.x := Clamp(AValue.x, EPS, Pi - EPS);
  AValue.y := Clamp(AValue.y, EPS, Pi - EPS);
  if FAngles = AValue then Exit;
  FAngles := AValue;
  InvalidateLight;
end;

procedure TavSpotLight.SetColor(const AValue: TVec3);
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  InvalidateLight;
end;

procedure TavSpotLight.SetDir(const AValue: TVec3);
begin
  if LenSqr(AValue) = 0 then Exit;
  if FDir = AValue then Exit;
  FDir := AValue;
  InvalidateLight;
end;

procedure TavSpotLight.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
  InvalidateLight;
end;

procedure TavSpotLight.SetRadius(const AValue: Single);
begin
  if FRadius = AValue then Exit;
  FRadius := AValue;
  InvalidateLight;
end;

procedure TavSpotLight.SetSize(const AValue: Single);
begin
  if FSize = AValue then Exit;
  FSize := AValue;
  InvalidateLight;
end;

function TavSpotLight.AllocShadowSlices: IShadowSlice;
begin
  if FCastShadows = stNone then
    Result := nil
  else
    Result := LightRenderer.Spots(FCastShadows).AllocShadowSlice;
end;

procedure TavSpotLight.ValidateLight(const AMain: TavMainRender);

  function GetProjMatrix(const AFov, ARad: Single; const ADepthRange: TVec2): TMat4;
  var h, Q: Single;
      DepthSize: Single;
      NearPlane, FarPlane: Single;
  begin
    FarPlane := ARad;
    NearPlane := FarPlane / 10000;
    h := (cos(AFov/2)/sin(AFov/2));
    Q := 1.0/(NearPlane - FarPlane);
    DepthSize := ADepthRange.y - ADepthRange.x;

    ZeroClear(Result, SizeOf(Result));
    Result.f[0, 0] := h;
    Result.f[1, 1] := h;
    Result.f[2, 2] := ADepthRange.x - DepthSize * FarPlane * Q;
    Result.f[2, 3] := 1.0;
    Result.f[3, 2] := DepthSize * NearPlane * FarPlane * Q;
  end;

  function BuildMatrix: TShadowMatrix;
  var mRot: TMat3;
      mView: TMat4;
      mProj: TMat4;
      mViewProj: TMat4;
  begin
    mRot.Row[2] := normalize(Dir);
    mRot.Row[1] := Cross(Dir, Vec(1,0,0));
    if LenSqr(mRot.Row[1]) < 0.01 then
    begin
      mRot.Row[1] := Cross(Dir, Vec(0,1,0));
      if LenSqr(mRot.Row[1]) < 0.01 then
        mRot.Row[1] := Cross(Dir, Vec(0,0,1));
    end;
    mRot.Row[1] := normalize(mRot.Row[1]);
    mRot.Row[0] := Cross(mRot.Row[1], mRot.Row[2]);
    mRot := Transpose(mRot);

    mView := IdentityMat4;
    mView.OX := mRot.Row[0];
    mView.OY := mRot.Row[1];
    mView.OZ := mRot.Row[2];
    mView.Pos := -Pos*mRot;

    mProj := GetProjMatrix(FAngles.y, FRadius, AMain.Projection.DepthRange);

    mViewProj := mView * mProj;
    Result.viewProj := mViewProj;
    Result.projInv := Inv(mProj);
    Result.proj := mProj;
    Result.view := mView;
  end;
var pld: PLightData;
begin
  FMatricesHandle := nil;
  pld := LightRenderer.FLightsData.PItem[FLightIndex];
  pld^.PosRange := Vec(FPos, FRadius);
  pld^.Color := FColor;
  pld^.Dir := normalize(FDir);
  pld^.Angles := Vec(cos(FAngles.x*0.5), cos(FAngles.y*0.5));
  pld^.LightSize := FSize;
  if FCastShadows <> stNone then
  begin
    FMatrices.Item[0] := BuildMatrix;
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

function TavSpotLight.InFrustum(const AFrustum: TFrustum): Boolean;
begin
  Result := LightIntersectFrusum(Pos, Dir, Radius, cos(FAngles.y*0.5), AFrustum);
end;

procedure TavSpotLight.AfterConstruction;
begin
  inherited AfterConstruction;
  FMatrices := TShadowMatrixArr.Create();
  FMatrices.SetSize(1);
  FDir := Vec(0,-1,0);
  FSize := 0.2;
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

function TavPointLightAdapter.GetSize: Single;
begin
  if FLight = nil then Exit(0);
  Result := FLight.Size;
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

procedure TavPointLightAdapter.SetSize(const AValue: Single);
begin
  if FLight = nil then Exit();
  FLight.Size := AValue;
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

function TavLightSourceAdapter.GetCastShadows: TShadowsType;
begin
  if GetLightSource = nil then Exit(stNone);
  Result := GetLightSource.CastShadows;
end;

procedure TavLightSourceAdapter.SetCastShadows(const AValue: TShadowsType);
begin
  if GetLightSource = nil then Exit();
  GetLightSource.CastShadows := AValue;
end;

function TavLightSourceAdapter.ShadowSlice: IShadowSlice;
begin
  if GetLightSource = nil then Exit(nil);
  Result := GetLightSource.ShadowSlice;
end;

function TavLightSourceAdapter.Matrices: PShadowMatrix;
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
              .Add('ViewMatRow0', ctFloat, 4)
              .Add('ViewMatRow1', ctFloat, 4)
              .Add('ViewMatRow2', ctFloat, 4)
              .Add('ViewMatRow3', ctFloat, 4)
              .Add('ProjRow0', ctFloat, 4)
              .Add('ProjRow1', ctFloat, 4)
              .Add('ProjRow2', ctFloat, 4)
              .Add('ProjRow3', ctFloat, 4)
              .Add('ProjInvMatRow0', ctFloat, 4)
              .Add('ProjInvMatRow1', ctFloat, 4)
              .Add('ProjInvMatRow2', ctFloat, 4)
              .Add('ProjInvMatRow3', ctFloat, 4)
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

function TavShadowTextures.AllocSlice(): TVec3i;
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
  FTexH.AllocMem(FTextureSize, FTextureSize, Length(FSlices)*FClusterSize, FWithMips, True);
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

constructor TavShadowTextures.Create(AOwner: TavObject; ATextureSize,
  AClusterSize: Integer; AWithMips: Boolean);
begin
  Create(AOwner);
  FTextureSize := ATextureSize;
  FClusterSize := AClusterSize;
  FWithMips    := AWithMips;
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
    mProjInv: TMat4;
    i: Integer;
begin
  mProj := CalcPerspectiveMatrix;
  mProjInv := Inv(mProj);

  SetViewMatrix(sm[0].view, APos, APos + Vec( 100, 0, 0), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_X
  SetViewMatrix(sm[1].view, APos, APos + Vec(-100, 0, 0), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_X
  SetViewMatrix(sm[2].view, APos, APos + Vec(0,  100, 0), Vec(0, 0, -1)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Y
  SetViewMatrix(sm[3].view, APos, APos + Vec(0, -100, 0), Vec(0, 0, 1)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Y
  SetViewMatrix(sm[4].view, APos, APos + Vec(0, 0,  100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_POSITIVE_Z
  SetViewMatrix(sm[5].view, APos, APos + Vec(0, 0, -100), Vec(0, 1, 0)); //GL_TEXTURE_CUBE_MAP_NEGATIVE_Z

  for i := 0 to 5 do
  begin
    sm[i].viewProj := sm[i].view * mProj;
    sm[i].proj := mProj;
    sm[i].projInv := mProjInv;
  end;
end;

{ TLightData }

class function TLightData.Layout: IDataLayout;
begin
  Result := LB.Add('PosRange', ctFloat, 4)
              .Add('LightSize', ctFloat, 1)
              .Add('Color', ctFloat, 3)
              .Add('Dir', ctFloat, 3)
              .Add('Angles', ctFloat, 2)
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

procedure TavPointLight.SetSize(const AValue: Single);
begin
  if FSize = AValue then Exit;
  FSize := AValue;
  InvalidateLight;
end;

function TavPointLight.AllocShadowSlices: IShadowSlice;
begin
  if FCastShadows = stNone then
    Result := nil
  else
    Result := LightRenderer.Cubes(FCastShadows).AllocShadowSlice;
end;

procedure TavPointLight.ValidateLight(const AMain: TavMainRender);
var pld: PLightData;
begin
  FMatricesHandle := nil;
  pld := LightRenderer.FLightsData.PItem[FLightIndex];
  pld^.PosRange := Vec(FPos, FRadius);
  pld^.Color := FColor;
  pld^.Dir := Vec(0,0,0);
  pld^.Angles := Vec(0,0);
  pld^.LightSize := FSize;
  if (FCastShadows <> stNone) and (AMain.ActiveApi <> apiDX11_WARP) then
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

function TavPointLight.InFrustum(const AFrustum: TFrustum): Boolean;
begin
  Result := LightIntersectFrusum(Pos, Vec(0,0,0), Radius, 0, AFrustum);
end;

procedure TavPointLight.AfterConstruction;
begin
  inherited AfterConstruction;
  FMatrices := TShadowMatrixArr.Create();
  FMatrices.SetSize(6);
  FSize := 0.2;
end;

{ TavLightSource }

procedure TavLightSource.SetCastShadows(const AValue: TShadowsType);
begin
  if FCastShadows = AValue then Exit;
  FCastShadows := AValue;
  FShadowSlice := AllocShadowSlices();
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

function TavLightSource.Matrices: PShadowMatrix;
begin
  Result := PShadowMatrix(FMatrices.PItem[0]);
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

function TavLightSource.InFrustum(const AFrustum: TFrustum): Boolean;
begin
  Result := False;
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
  ZeroClear(ld, SizeOf(ld));
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
  LightRenderer.FInvalidLights.Delete(Self);
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

function TavLightRenderer.AddPointLight(): IavPointLight;
begin
  Result := TavPointLightAdapter.Create(TavPointLight.Create(Self));
end;

function TavLightRenderer.AddDirectionalLight(): IavDirectionalLight;
begin
  //todo
  Assert(False);
  Result := nil;
end;

function TavLightRenderer.AddSpotLight(): IavSpotLight;
begin
  Result := TavSpotLightAdapter.Create(TavSpotLight.Create(Self));
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

  pbox: TAABB;
  f: TFrustum;
begin
  BuildHeadBuffer;

//  fbo := FCubes512.GetFBOAll();
//  fbo.FrameRect := RectI(0, 0, FCubes512.TextureSize, FCubes512.TextureSize);
//  fbo.Select();
//  fbo.ClearDS(Main.Projection.DepthRange.y);

  pbox.min := Vec(-1,-1,Main.Projection.DepthRange.x);
  pbox.max := Vec( 1, 1,Main.Projection.DepthRange.y);
  f.Init(Inv(Main.Camera.Matrix * Main.Projection.Matrix), pbox);

  for i := 0 to FLights.Count - 1 do
  begin
    if not FLights[i].InFrustum(f) then
      Continue;
    if FLights[i].CastShadows = stNone then
      Continue;

    ld := FLightsData[i];
    if (ld.ShadowSizeSliceRange.y >= 0) then
    begin
      if LenSqr(ld.Dir) = 0 then
      begin
        fbo := FCubes[FLights[i].CastShadows].GetFBO(ld.ShadowSizeSliceRange);
      end
      else
      begin
        fbo := FSpots[FLights[i].CastShadows].GetFBO(ld.ShadowSizeSliceRange);
      end;
      fbo.FrameRect := RectI(0, 0, ld.ShadowSizeSliceRange.x, ld.ShadowSizeSliceRange.x);
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

function TavLightRenderer.Cubes(const AType: TShadowsType): TavShadowTextures;
begin
  Result := FCubes[AType];
end;

function TavLightRenderer.Spots(const AType: TShadowsType): TavShadowTextures;
begin
  Result := FSpots[AType];
end;

procedure TavLightRenderer.AfterConstruction;
var cSize: TVec3i;
    st: TShadowsType;
begin
  inherited AfterConstruction;
  cSize := Vec(4,4,4)*4;
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

  for st := st64 to st2048 do
  begin
    FCubes[st] := TavShadowTextures.Create(Self, cShadowsTypeSize[st], 6, False);
    FSpots[st] := TavShadowTextures.Create(Self, cShadowsTypeSize[st], 1, False);
  end;

  FLightMatricesSB := TavSBManaged.Create(Self);
end;

end.

