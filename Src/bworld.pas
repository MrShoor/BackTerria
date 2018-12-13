unit bWorld;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils,
  avRes,
  avContnrs,
  mutils,
  bLights,
  bPostProcess,
  bMiniParticles,
  bBassLight,
  bAutoColliders,
  bCubeUtils,
  avBase,
  avTypes,
  avMesh,
  avModel,
  avCanvas;

{$I bshaders.inc}
{$IfDef FPC}
  {$R 'shaders\shaders.rc'}
{$Else}
  {$R 'shaders\shaders.res'}
{$EndIf}

type
  TbWorld = class;

  TModelType = (mtDefault, mtEmissive, mtTransparent);

  IOverrideColorArr = {$IfDef FPC}specialize{$EndIf} IArray<TVec3>;
  TOverrideColorArr = {$IfDef FPC}specialize{$EndIf} TArray<TVec3>;

  { TbGameObject }

  TbGameObject = class (TavMainRenderChild)
  private
    FBBox: TAABB;

    FPos: TVec3;
    FRot: TQuat;
    FScale: Single;
    FTransform: TMat4;
    FTransformInv: TMat4;
  protected
    FTransformValid: Boolean;
    procedure UpdateAtTree;
    procedure ValidateTransform; virtual;
    procedure AfterValidateTransform; virtual;
    procedure InvalidateTransform; virtual;
    function  GetPos: TVec3; virtual;
    function  GetRot: TQuat; virtual;
    procedure SetBBox(const AValue: TAABB); virtual;
    procedure SetPos(const AValue: TVec3); virtual;
    procedure SetRot(const AValue: TQuat); virtual;
    procedure SetScale(const AValue: Single); virtual;
  protected
    FStatic: Boolean;
    function  GetStatic: Boolean; virtual;
    procedure SetStatic(const AValue: Boolean); virtual;
  protected
    FSubscribed: Boolean;
    FUnsubscribeTime: Int64;
    procedure SubscribeForUpdateStep(const ASubscribeDuration: Integer = -1);
    procedure UnSubscribeFromUpdateStep;
    procedure UpdateStep; virtual;
    procedure RegisterAsUIObject;
    procedure UnRegisterAsUIObject;
  protected
    FWorld: TbWorld;
    function CanRegister(target: TavObject): boolean; override;
  protected
    FModels: IavModelInstanceArr;
    FEmissive: IavModelInstanceArr;
    FTransparent: IavModelInstanceArr;
  public
    procedure ClearModels(AType: TModelType); virtual;
    procedure AddModel(const AName: string; AType: TModelType = mtDefault); virtual;
    procedure WriteModels(const ACollection: IavModelInstanceArr; AType: TModelType); virtual;
    procedure WriteDepthOverrideModels(const ACollection: IavModelInstanceArr; const ADepthOverride: IOverrideColorArr); virtual;
    procedure WriteParticles(const ACollection: IParticlesHandleArr); virtual;

    function  UIIndex: Integer; virtual;
    procedure UIDraw(); virtual;
  public
    property World: TbWorld read FWorld;

    property Pos  : TVec3  read GetPos write SetPos;
    property Rot  : TQuat  read GetRot write SetRot;
    property Scale: Single read FScale write SetScale;
    property BBox : TAABB  read FBBox  write SetBBox;

    function Transform(): TMat4;
    function TransformInv(): TMat4;
    function AbsBBox(): TAABB;

    property Static: Boolean read GetStatic write SetStatic;

    function GetVisible(): Boolean; virtual;

    procedure AfterConstruction; override;
    constructor Create(AParent: TavObject); override;
    destructor Destroy; override;
  end;
  TbGameObjArr = {$IfDef FPC}specialize{$EndIf}TArray<TbGameObject>;
  IbGameObjArr = {$IfDef FPC}specialize{$EndIf}IArray<TbGameObject>;
  TbGameObjSet = {$IfDef FPC}specialize{$EndIf}THashSet<TbGameObject>;
  IbGameObjSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TbGameObject>;
  TbGameObjClass = class of TbGameObject;

  IbGameObjTree = {$IfDef FPC}specialize{$EndIf}ILooseOctTree<TbGameObject>;
  TbGameObjTree = {$IfDef FPC}specialize{$EndIf}TLooseOctTree<TbGameObject>;
  IbGameObjTreeNode = {$IfDef FPC}specialize{$EndIf} IBase_LooseTreeNode<TbGameObject, TAABB>;

  { TbCollisionObject }

  TbCollisionObject = class (TbGameObject)
  protected
    FDefaultCollider: ICollider;
    FDefaultColliderOffset: TVec3;
    function  GetPos: TVec3; override;
    procedure SetPos(const AValue: TVec3); override;
  public
    property DefaultCollider: ICollider read FDefaultCollider;
  end;

  { TbDynamicCollisionObject }

  TbDynamicCollisionObject = class (TbCollisionObject)
  protected
    procedure UpdateStep; override;
  public
    procedure AfterConstruction; override;
  end;

  (*
  { TbPhysObject }

  TbPhysObject = class (TbGameObject)
  protected
    FBody: IPhysBody;

    function  GetPos: TVec3; override;
    function  GetRot: TQuat; override;
    procedure SetPos(const AValue: TVec3); override;
    procedure SetRot(const AValue: TQuat); override;
  protected
    function CreatePhysBody: IPhysBody; virtual; abstract;
  public
    property Body: IPhysBody read FBody;
    procedure AfterConstruction; override;
  end;

  { TbDynamicObject }

  TbDynamicObject = class (TbPhysObject)
  protected
    procedure UpdateStep; override;
  public
    procedure AfterConstruction; override;
  end;
  *)

  { TbGraphicalObject }

  TbGraphicalObject = class (TavMainRenderChild)
  private
    FPos: TVec3;
    FCanvas: TavCanvas;
    function GetPos: TVec3;
    procedure SetPos(const AValue: TVec3);
  protected
    FWorld: TbWorld;
    function CanRegister(target: TavObject): boolean; override;
    procedure AfterRegister; override;
  protected
    FMarkedForDestroy : Boolean;
    procedure UpdateStep; virtual;
    procedure SafeDestroy;
    property  MarkedForDestroy: Boolean read FMarkedForDestroy;
  public
    property World: TbWorld read FWorld;
    property Pos  : TVec3 read GetPos write SetPos;

    property Canvas: TavCanvas read FCanvas;

    procedure Draw(); virtual;

    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;
  TbGraphicalObjectArr = {$IfDef FPC}specialize{$EndIf}TArray<TbGraphicalObject>;
  IbGraphicalObjectArr = {$IfDef FPC}specialize{$EndIf}IArray<TbGraphicalObject>;
  TbGraphicalObjectSet = {$IfDef FPC}specialize{$EndIf}THashSet<TbGraphicalObject>;
  IbGraphicalObjectSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TbGraphicalObject>;

  { TbWorldRenderer }

  TbWorldRenderer = class (TavMainRenderChild)
  private type
    TShadowPassAdapter = class(TInterfacedObject, IGeometryRenderer)
    private
      FOwner: TbWorldRenderer;
      FViewProjMat: TMat4Arr;

      FQueryResult: IbGameObjArr;
      FAllModels: IavModelInstanceArr;

      procedure PreapreObjects(const ALight: TavLightSource; out AHasDynamic: Boolean);
      procedure ShadowPassGeometry(const ALight: TavLightSource; const ALightData: TLightData);
      procedure DrawTransparentGeometry();
    public
      constructor Create(AOwner: TbWorldRenderer);
    end;
  private
    FLightRenderer: TavLightRenderer;
    FShadowPassAdapter: IGeometryRenderer;
    FPostProcess: TavPostProcess;

    FParticles: TbParticleSystem;

    FST_Albedo        : TavTexture;
    FST_Normals       : TavTexture;
    FST_Material      : TavTexture;
    FST_Depth         : TavTexture;
    FST_Emission      : TavTexture;
    FST_Lighted       : TavTexture;

    FGBufferForOpacity: TavFrameBuffer;
    FGBufferForLightPass: TavFrameBuffer;
    FGBufferForTransparent: TavFrameBuffer;
    FGBufferDepthOverride: TavFrameBuffer;
    FEmissionFBO: TavFrameBuffer;

    FCubeUtils: TbCubeUtils;
    FEnviromentFile: string;
    FEnviromentCube: TEnviroment;
    FEnviromentAmbient: TVec3;
    FEnviromentAsColor: Boolean;
    FbrdfLUT: TavTexture;

    FModelsProgram: TavProgram;
    FModelsProgram_NoLight: TavProgram;
    FModelsPBRProgramToGBuffer: TavProgram;
    FModelsPBRProgramLightPass: TavProgram;
    FModelsPBRProgram: TavProgram;
    FModelsShadowProgram: TavProgram;
    FModelsEmissionProgram: TavProgram;
    FModelsMeshOverrideProgram: TavProgram;

    FCubeDrawProgram: TavProgram;

    FModels: TavModelCollection;
    FPrefabs: IavMeshInstances;
  protected
    FWorld: TbWorld;
    property World: TbWorld read FWorld;
    function CanRegister(target: TavObject): boolean; override;
    procedure AfterRegister; override;
  protected
    FAllModels: IavModelInstanceArr;
    FAllModelsPostOverride: IavModelInstanceArr;
    FOverrideModelsArr : IavModelInstanceArr;
    FOverrideModelsSet : IavModelInstanceSet;
    FOverrideColors : IOverrideColorArr;
    FQueryResult: IbGameObjArr;

    FOnAfterDraw: TNotifyEvent;
    procedure UpdateVisibleObjects;
    procedure UpdateAllModels(AModelType: TModelType);
    procedure UpdateAllOverrideModels();
  protected
    FGObjs: IbGraphicalObjectSet;
    procedure RegisterGraphicalObject(const gobj: TbGraphicalObject);
    procedure UnregisterGraphicalObject(const gobj: TbGraphicalObject);
  public
    property OnAfterDraw: TNotifyEvent read FOnAfterDraw write FOnAfterDraw;

    procedure InvalidateShaders;
    function GraphicalObjects: IbGraphicalObjectSet;

    procedure PrepareToDraw;
    procedure DrawWorld;

    function CreatePointLight(): IavPointLight;
    function CreateSpotLight(): IavSpotLight;

    function FindPrefabInstances(const AName: string): IavMeshInstance;
    function CreateModelInstances(const ANames: array of string): IavModelInstanceArr;
    function Particles: TbParticleSystem;

    procedure PreloadModels(const AFiles: array of string);

    procedure SetEnviromentAmbient(const AAmbientColor: TVec3);
    procedure SetEnviromentCubemap(const AFileName: string);
  public
    property ModelsProgram_NoLight: TavProgram read FModelsProgram_NoLight;
    property ModelsCollection: TavModelCollection read FModels;
  end;

  { TbWorld }

  TbWorld = class (TavMainRenderChild)
  private type
    TTree_Iterator = class(TInterfacedObject, ILooseNodeCallBackIterator)
    private type
      TCheckType = (ctViewProj, ctAABB, ctLine);
    private
      FCheckType : TCheckType;
      FViewProj  : TMat4;
      FDepthRange: TVec2;
      FAABB      : TAABB;
      FResult    : IbGameObjArr;
    public
      procedure OnEnumNode(const ASender: IInterface; const ANode: IInterface; var EnumChilds: Boolean);
      constructor Create(const AResult: IbGameObjArr; const AViewProj: TMat4; const ADepthRange: TVec2);
      constructor Create(const AResult: IbGameObjArr; const ABox: TAABB);
    end;
  private
    FTree: IbGameObjTree;
    FTreeToAdd : IbGameObjSet;

    FObjects   : IbGameObjSet;
    FToDestroy : IbGameObjSet;
    FUpdateSubs: IbGameObjSet;
    FTempObjs  : IbGameObjArr;
    FGObjsToDestroy: IbGraphicalObjectArr;

    FStaticForUpdate: IbGameObjSet;

    FUIObjects : IbGameObjSet;
    FWorldState: TbGameObject;

    FTimeTick: Int64;

    FRenderer : TbWorldRenderer;
    FColliders: IAutoCollidersGroup;
    //FPhysics  : IPhysWorld;
    FSndPlayer: ILightPlayer;

    function GetGameTime: Int64;
    procedure SetWorldState(const AValue: TbGameObject);
  private
    procedure Process_TreeToAdd;
  public
    property Renderer : TbWorldRenderer read FRenderer;
    //property Physics  : IPhysWorld read FPhysics;
    property Colliders: IAutoCollidersGroup read FColliders;
    property SndPlayer: ILightPlayer read FSndPlayer;

    function QueryObjects(const AViewProj: TMat4): IbGameObjArr; overload;
    function QueryObjects(const ABox: TAABB): IbGameObjArr; overload;
    function QueryObjects(const ARay: TLine): IbGameObjArr; overload;
    function UIObjects: IbGameObjSet;

    property GameTime: Int64 read GetGameTime;

    procedure UpdateStep(AStepCount: Integer = 1);
    procedure SafeDestroy(const AObj: TbGameObject);
    procedure ProcessToDestroy;

    property WorldState: TbGameObject read FWorldState write SetWorldState;

    procedure AfterConstruction; override;
  end;

implementation

uses avTexLoader;

type

  { TTexRemapper }

  TTexRemapper = class(TInterfacedObject, IMeshLoaderCallback)
  private type
    ITexRemap = {$IfDef FPC}specialize{$EndIf} IHashMap<string, string>;
    TTexRemap = {$IfDef FPC}specialize{$EndIf} THashMap<string, string>;
  private
    FTexRemap: ITexRemap;
    function Hook_TextureFilename(const ATextureFilename: string): string;

    procedure OnLoadingMesh(const AMesh: string);
    procedure OnLoadingMaterial(const AMaterial: TMeshMaterial);
    procedure OnLoadingTexture(const AKind: TMeshMaterialTextureKind; const AFileName: string; const ASize: TVec2i; const AFactor: Single);
  public
    constructor Create(const AFileName: string);
  end;

var gvCounter: Int64;

{ TbWorld.TTree_Iterator }

procedure TbWorld.TTree_Iterator.OnEnumNode(const ASender: IInterface; const ANode: IInterface; var EnumChilds: Boolean);
var box: TAABB;
    tree: IbGameObjTree absolute ASender;
    node: IbGameObjTreeNode absolute ANode;
    i: Integer;
    addItem: Boolean;
begin
  box := tree.AABB(ANode);
  case FCheckType of
    ctViewProj:
        EnumChilds := box.InFrustum(FViewProj, FDepthRange);
    ctAABB:
        EnumChilds := Intersect(box, FAABB);
  else
    EnumChilds := False;
  end;

  if EnumChilds then
  begin
    for i := 0 to node.ItemsCount - 1 do
    begin
      if not node.Item(i).GetVisible() then Continue;
      box := node.Item(i).AbsBBox;

      case FCheckType of
        ctViewProj: addItem := box.InFrustum(FViewProj, FDepthRange);
        ctAABB: addItem := Intersect(box, FAABB);
      else
        addItem := False;
      end;

      if addItem then
        FResult.Add(node.Item(i));
    end;
  end;
end;

constructor TbWorld.TTree_Iterator.Create(const AResult: IbGameObjArr; const AViewProj: TMat4; const ADepthRange: TVec2);
begin
  FResult := AResult;
  FViewProj := AViewProj;
  FCheckType := ctViewProj;
  FDepthRange := ADepthRange;
end;

constructor TbWorld.TTree_Iterator.Create(const AResult: IbGameObjArr; const ABox: TAABB);
begin
  FResult := AResult;
  FAABB := ABox;
  FCheckType := ctAABB;
end;

{ TTexRemapper }

function TTexRemapper.Hook_TextureFilename(const ATextureFilename: string): string;
begin
  if not FTexRemap.TryGetValue(ATextureFilename, Result) then
    Result := ATextureFilename;
end;

procedure TTexRemapper.OnLoadingMesh(const AMesh: string);
begin

end;

procedure TTexRemapper.OnLoadingMaterial(const AMaterial: TMeshMaterial);
begin

end;

procedure TTexRemapper.OnLoadingTexture(const AKind: TMeshMaterialTextureKind;
  const AFileName: string; const ASize: TVec2i; const AFactor: Single);
begin

end;

constructor TTexRemapper.Create(const AFileName: string);
var fs: TFileStream;
    n, i: Integer;
    src, dst: AnsiString;
begin
  FTexRemap := TTexRemap.Create();
  if FileExists(AFileName) then
  begin
    fs := TFileStream.Create(AFileName, fmOpenRead);
    try
      fs.ReadBuffer(n, SizeOf(n));
      FTexRemap.Capacity := NextPow2(n)*2;
      for i := 0 to n - 1 do
      begin
        StreamReadString(fs, src);
        StreamReadString(fs, dst);
        FTexRemap.AddOrSet(src, dst);
      end;
    finally
      FreeAndNil(fs);
    end;
  end;
end;

{ TbGraphicalObject }

function TbGraphicalObject.GetPos: TVec3;
begin
  Result := FPos;
end;

procedure TbGraphicalObject.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
end;

function TbGraphicalObject.CanRegister(target: TavObject): boolean;
begin
  Result := inherited CanRegister(target);
  if not Result then Exit;
  FWorld := TbWorld(target.FindAtParents(TbWorld));
  Result := Assigned(FWorld);
end;

procedure TbGraphicalObject.AfterRegister;
begin
  inherited AfterRegister;
  World.Renderer.RegisterGraphicalObject(self);
end;

procedure TbGraphicalObject.UpdateStep;
begin

end;

procedure TbGraphicalObject.SafeDestroy;
begin
  FMarkedForDestroy := True;
end;

procedure TbGraphicalObject.Draw;
var pp: TVec4;
    range: TVec2;
begin
  pp := Vec(FPos, 1.0) * Main.Camera.Matrix * Main.Projection.Matrix;
  pp.xyz := pp.xyz / pp.w;
  range := Main.Projection.DepthRangeMinMax;
  if (pp.z < range.x) or (pp.z > range.y) then Exit;

  pp.xy := (pp.xy*Vec(0.5,-0.5) + Vec(0.5, 0.5)) * Main.WindowSize;

  FCanvas.ZValue := pp.z;
  FCanvas.Draw(0, pp.xy, 1);
end;

procedure TbGraphicalObject.AfterConstruction;
begin
  inherited AfterConstruction;
  FCanvas := TavCanvas.Create(Self);
end;

destructor TbGraphicalObject.Destroy;
begin
  FWorld.Renderer.UnregisterGraphicalObject(self);
  inherited Destroy;
end;

{ TbDynamicCollisionObject }

procedure TbDynamicCollisionObject.UpdateStep;
begin
  inherited UpdateStep;
  if FDefaultCollider <> nil then
    FTransformValid := False;
end;

procedure TbDynamicCollisionObject.AfterConstruction;
begin
  inherited AfterConstruction;
  SubscribeForUpdateStep;
end;

{ TbCollisionObject }

function TbCollisionObject.GetPos: TVec3;
begin
  if FDefaultCollider <> nil then
    Result := FDefaultCollider.Pos - FDefaultColliderOffset
  else
    Result := inherited;
end;

procedure TbCollisionObject.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  inherited SetPos(AValue);
  if FDefaultCollider <> nil then
    FDefaultCollider.Pos := AValue - FDefaultColliderOffset;
end;

(*
{ TbPhysObject }

function TbPhysObject.GetPos: TVec3;
begin
  if FBody <> nil then
    Result := FBody.GetPos
  else
    Result := inherited;
end;

function TbPhysObject.GetRot: TQuat;
begin
  if FBody <> nil then
    Result := FBody.GetRot
  else
    Result := inherited;
end;

procedure TbPhysObject.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  inherited SetPos(AValue);
  if FBody <> nil then
    FBody.Pos := AValue;
end;

procedure TbPhysObject.SetRot(const AValue: TQuat);
begin
  if FRot = AValue then Exit;
  inherited SetRot(AValue);
  if FBody <> nil then
    FBody.Rot := AValue;
end;

procedure TbPhysObject.AfterConstruction;
begin
  inherited AfterConstruction;
  FModels := TavModelInstanceArr.Create();
  FBody := CreatePhysBody;
  if FBody <> nil then
    FBody.Transform := Transform();
end;

{ TbDynamicObject }

procedure TbDynamicObject.UpdateStep;
begin
  inherited UpdateStep;
  FTransformValid := False;
end;

procedure TbDynamicObject.AfterConstruction;
begin
  inherited AfterConstruction;
  SubscribeForUpdateStep;
end;
*)
{ TbWorldRenderer.TShadowPassAdapter }

procedure TbWorldRenderer.TShadowPassAdapter.PreapreObjects(const ALight: TavLightSource; out AHasDynamic: Boolean);
var
  i: Integer;
begin
  if ALight.MatricesCount = 6 then //omnilight
    FQueryResult := FOwner.World.QueryObjects(ALight.BBox)
  else                                          //spotlight
    FQueryResult := FOwner.World.QueryObjects(ALight.Matrices^.viewProj);

  AHasDynamic := False;
  for i := 0 to FQueryResult.Count - 1 do
    if not FQueryResult[i].Static then
    begin
      AHasDynamic := True;
      Break;
    end;
end;

procedure TbWorldRenderer.TShadowPassAdapter.ShadowPassGeometry(const ALight: TavLightSource; const ALightData: TLightData);
var
  i: Integer;
  sm: PShadowMatrix;
begin
  if FQueryResult = nil then Exit;
  if FQueryResult.Count = 0 then Exit;

  sm := ALight.Matrices;
  for i := 0 to ALightData.ShadowSizeSliceRangeMode.z - 1 do
  begin
    FViewProjMat[i] := sm^.viewProj;
    Inc(sm);
  end;

  FAllModels.Clear();
  for i := 0 to FQueryResult.Count - 1 do
    FQueryResult[i].WriteModels(FAllModels, mtDefault);

  FOwner.FModelsShadowProgram.Select;
  FOwner.FModelsShadowProgram.SetUniform('matCount', ALightData.ShadowSizeSliceRangeMode.z);
  FOwner.FModelsShadowProgram.SetUniform('sliceOffset', Integer(round(ALightData.ShadowSizeSliceRangeMode.y)));
  FOwner.FModelsShadowProgram.SetUniform('viewProj', @FViewProjMat[0], ALightData.ShadowSizeSliceRangeMode.z);
  FOwner.FModels.Select;
  FOwner.FModels.Draw(FAllModels, False);
end;

procedure TbWorldRenderer.TShadowPassAdapter.DrawTransparentGeometry();
begin

end;

constructor TbWorldRenderer.TShadowPassAdapter.Create(AOwner: TbWorldRenderer);
begin
  FOwner := AOwner;
  SetLength(FViewProjMat, 6);

  FQueryResult := TbGameObjArr.Create();
  FAllModels := TavModelInstanceArr.Create();
end;

{ TbWorldRenderer }

function TbWorldRenderer.CanRegister(target: TavObject): boolean;
begin
  Result := inherited CanRegister(target);
  if not Result then Exit;
  FWorld := TbWorld(target.FindAtParents(TbWorld));
  Result := Assigned(FWorld);
end;

procedure TbWorldRenderer.AfterRegister;
  procedure CreateScreenTextures();
  begin
    FST_Albedo := TavTexture.Create(Self);
    FST_Albedo.TargetFormat := TTextureFormat.RGBA;
    FST_Albedo.AutoGenerateMips := False;

    FST_Normals := TavTexture.Create(Self);
    FST_Normals.TargetFormat := TTextureFormat.RGBA;
    FST_Normals.AutoGenerateMips := False;

    FST_Material := TavTexture.Create(Self);
    FST_Material.TargetFormat := TTextureFormat.RGBA;
    FST_Material.AutoGenerateMips := False;

    FST_Depth := TavTexture.Create(Self);
    FST_Depth.TargetFormat := TTextureFormat.D32f;
    FST_Depth.AutoGenerateMips := False;

    FST_Lighted := TavTexture.Create(Self);
    FST_Lighted.TargetFormat := TTextureFormat.RGBA16f;
    FST_Lighted.AutoGenerateMips := False;

    FST_Emission := TavTexture.Create(Self);
    FST_Emission.TargetFormat := TTextureFormat.RGBA16f;
    FST_Emission.AutoGenerateMips := True;
  end;

begin
  inherited AfterRegister;
  CreateScreenTextures();

  FLightRenderer := TavLightRenderer.Create(Self);
  FShadowPassAdapter := TShadowPassAdapter.Create(Self);
  FParticles := TbParticleSystem.Create(Self);

  FPostProcess := TavPostProcess.Create(Self);

  FGBufferForOpacity := Create_FrameBuffer(Self, [FST_Albedo, FST_Normals, FST_Material, FST_Depth]);
  FGBufferForLightPass := Create_FrameBuffer(Self, [FST_Lighted]);
  FGBufferForTransparent := Create_FrameBuffer(Self, [FST_Lighted, FST_Depth]);
  FGBufferDepthOverride := Create_FrameBuffer(Self, [FST_Albedo, FST_Depth]);
  FEmissionFBO := Create_FrameBuffer(Self, [FST_Emission, FST_Depth]);

  FModelsProgram := TavProgram.Create(Self);
  FModelsProgram.Load('avMesh', SHADERS_FROMRES, SHADERS_DIR);
  FModelsProgram_NoLight := TavProgram.Create(Self);
  FModelsProgram_NoLight.Load('avMesh_NoLight', SHADERS_FROMRES, SHADERS_DIR);

  FModelsPBRProgramToGBuffer := TavProgram.Create(Self);
  FModelsPBRProgramToGBuffer.Load('avMeshPbrPackedToGBuffer', SHADERS_FROMRES, SHADERS_DIR);
  FModelsPBRProgramLightPass := TavProgram.Create(Self);
  FModelsPBRProgramLightPass.Load('avMeshPbrGLightPass', SHADERS_FROMRES, SHADERS_DIR);

  FModelsPBRProgram := TavProgram.Create(Self);
  //FModelsPBRProgram.Load('avMeshPBR', SHADERS_FROMRES, SHADERS_DIR);
  //FModelsPBRProgram.Load('avMeshTest', SHADERS_FROMRES, SHADERS_DIR);
  FModelsPBRProgram.Load('avMeshPbrPacked', SHADERS_FROMRES, SHADERS_DIR);
  FModelsShadowProgram := TavProgram.Create(Self);
  FModelsShadowProgram.Load('avMesh_shadow', SHADERS_FROMRES, SHADERS_DIR);
  FModelsEmissionProgram := TavProgram.Create(Self);
  FModelsEmissionProgram.Load('avMesh_emission', SHADERS_FROMRES, SHADERS_DIR);
  FModelsMeshOverrideProgram := TavProgram.Create(Self);
  FModelsMeshOverrideProgram.Load('avMeshDepthOverride', SHADERS_FROMRES, SHADERS_DIR);

  FCubeDrawProgram := TavProgram.Create(Self);
  FCubeDrawProgram.Load('cubemap_out', SHADERS_FROMRES, SHADERS_DIR);
  FModels := TavModelCollection.Create(Self);

  FCubeUtils := TbCubeUtils.Create(Self);
  SetEnviromentAmbient(Vec(0.2,0.2,0.2));

  FPrefabs := TavMeshInstances.Create();

  FGObjs := TbGraphicalObjectSet.Create();

  FAllModels := TavModelInstanceArr.Create();
  FAllModelsPostOverride := TavModelInstanceArr.Create();
  FOverrideModelsArr := TavModelInstanceArr.Create();
  FOverrideModelsSet := TavModelInstanceSet.Create();
  FOverrideColors := TOverrideColorArr.Create();
end;

procedure TbWorldRenderer.UpdateVisibleObjects;
var vp: TMat4;
begin
  vp := Main.Camera.Matrix * Main.Projection.Matrix;
  FQueryResult := World.QueryObjects(vp);
end;

procedure TbWorldRenderer.UpdateAllModels(AModelType: TModelType);
var
  i: Integer;
begin
  FAllModels.Clear();
  for i := 0 to FQueryResult.Count - 1 do
    FQueryResult[i].WriteModels(FAllModels, AModelType);

  if AModelType = TModelType.mtDefault then
  begin
    FAllModelsPostOverride.Clear();
    for i := FAllModels.Count - 1 downto 0 do
      if FOverrideModelsSet.Contains(FAllModels[i]) then
      begin
        FAllModelsPostOverride.Add(FAllModels[i]);
        FAllModels.DeleteWithSwap(i);
      end;
  end;
end;

procedure TbWorldRenderer.UpdateAllOverrideModels();
var
  i: Integer;
begin
  FOverrideModelsArr.Clear();
  FOverrideColors.Clear();
  FOverrideModelsSet.Clear();
  for i := 0 to FQueryResult.Count - 1 do
    FQueryResult[i].WriteDepthOverrideModels(FOverrideModelsArr, FOverrideColors);

  for i := 0 to FOverrideModelsArr.Count - 1 do
    FOverrideModelsSet.Add(FOverrideModelsArr[i]);
end;

procedure TbWorldRenderer.RegisterGraphicalObject(const gobj: TbGraphicalObject);
begin
  FGObjs.Add(gobj);
end;

procedure TbWorldRenderer.UnregisterGraphicalObject(const gobj: TbGraphicalObject);
begin
  FGObjs.Delete(gobj);
end;

procedure TbWorldRenderer.InvalidateShaders;
begin
  FLightRenderer.InvalidateShaders;
  FPostProcess.InvalidateShaders;
  FModelsProgram.Invalidate;
  FModelsProgram_NoLight.Invalidate;
  FModelsPBRProgram.Invalidate;
  FModelsEmissionProgram.Invalidate;
  FModelsMeshOverrideProgram.Invalidate;
  FModelsShadowProgram.Invalidate;
  FModelsPBRProgramToGBuffer.Invalidate;
  FModelsPBRProgramLightPass.Invalidate;
  FCubeUtils.InvalidateShaders;
end;

function TbWorldRenderer.GraphicalObjects: IbGraphicalObjectSet;
begin
  Result := FGObjs;
end;

procedure TbWorldRenderer.PrepareToDraw;
begin
  UpdateVisibleObjects();

  Main.States.DepthTest := True;

  Main.States.CullMode := cmFront;

  FLightRenderer.Render(FShadowPassAdapter);

  if not FEnviromentAsColor then
  begin
    if FEnviromentFile <> '' then
    begin
      FCubeUtils.GenEnviromentFromCube(FEnviromentCube, Self, FEnviromentFile);
      FEnviromentFile := '';
    end;
    if FbrdfLUT = nil then
    begin
      FbrdfLUT := TavTexture.Create(Self);
      FbrdfLUT.TargetFormat := TTextureFormat.RG16f;
      FCubeUtils.GenLUTbrdf(FbrdfLUT, 512);
    end;
  end;
end;

procedure TbWorldRenderer.DrawWorld;

  procedure SelectProgramForLighting(const prog: TavProgram);
  const
    cSampler_Cubes2 : TSamplerInfo = (
      MinFilter  : tfNearest;
      MagFilter  : tfNearest;
      MipFilter  : tfNearest;
      Anisotropy : 0;
      Wrap_X     : twClamp;
      Wrap_Y     : twClamp;
      Wrap_Z     : twClamp;
      Border     : (x: 0; y: 0; z: 0; w: 0);
      Comparison : cfNever;
    );
  var st: TShadowsType;
  begin
    prog.Select();
    prog.SetUniform('depthRange', Main.Projection.DepthRange);
    prog.SetUniform('planesNearFar', Vec(Main.Projection.NearPlane, Main.Projection.FarPlane));
    prog.SetUniform('lightCount', FLightRenderer.LightsCount*1.0);
    prog.SetUniform('light_list', FLightRenderer.LightsList);
    prog.SetUniform('light_headBufferSize', FLightRenderer.LightsHeadBuffer.Size*1.0);
    prog.SetUniform('light_headBuffer', FLightRenderer.LightsHeadBuffer, Sampler_NoFilter);
    prog.SetUniform('light_linkedList', FLightRenderer.LightsLinkedList);
    prog.SetUniform('light_matrices', FLightRenderer.LightMatrices);

    for st := st64 to st2048 do
    begin
      prog.SetUniform('ShadowCube'+IntToStr(cShadowsTypeSize[st]), FLightRenderer.Cubes(st), cSampler_Cubes2);
      prog.SetUniform('ShadowSpot'+IntToStr(cShadowsTypeSize[st]), FLightRenderer.Spots(st), cSampler_Cubes2);
    end;

    if FEnviromentAsColor then
    begin
      prog.SetUniform('EnvAmbientColor', Vec(FEnviromentAmbient, 1.0));
    end
    else
    begin
      prog.SetUniform('EnvAmbientColor', Vec(0.0,0.0,0.0,0.0));
      prog.SetUniform('EnvRadiance', FEnviromentCube.Radiance, Sampler_Linear);
      prog.SetUniform('EnvIrradiance', FEnviromentCube.Irradiance, Sampler_Linear);
      prog.SetUniform('brdfLUT', FbrdfLUT, Sampler_LinearClamped);
    end;
  end;

var gobj: TbGraphicalObject;
  i: Integer;
begin
  UpdateAllOverrideModels();

  Main.States.CullMode := cmBack;

  Main.States.Blending[AllTargets] := False;
 //opacity pass
  UpdateAllModels(mtDefault);
  FGBufferForOpacity.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FGBufferForOpacity.Select;
  FGBufferForOpacity.ClearDS(Main.Projection.DepthRange.y);
  FModelsPBRProgramToGBuffer.Select();
  FModels.Select();
  FModels.Draw(FAllModels);

 //depth override pass
  FGBufferDepthOverride.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FGBufferDepthOverride.Select();
  Main.States.DepthFunc := cfLess;
  Main.States.DepthWrite := False;
  Main.States.Blending[0] := True;
  FModelsMeshOverrideProgram.Select();
  FModels.Select;
  for i := 0 to FOverrideModelsArr.Count - 1 do
  begin
    FModelsMeshOverrideProgram.SetUniform('OverrideColor', FOverrideColors[i]);
    FModels.Draw(FOverrideModelsArr[i]);
  end;
  Main.States.Blending[0] := False;
  Main.States.DepthWrite := True;
  Main.States.DepthFunc := cfGreater;

 //opacity pass (post override)
  FGBufferForOpacity.Select;
  FModelsPBRProgramToGBuffer.Select();
  FModels.Select();
  FModels.Draw(FAllModelsPostOverride);

 //light pass
  FGBufferForLightPass.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FGBufferForLightPass.Select;
  SelectProgramForLighting(FModelsPBRProgramLightPass);
  FModelsPBRProgramLightPass.SetUniform('Albedo', FST_Albedo, Sampler_NoFilter);
  FModelsPBRProgramLightPass.SetUniform('Norm', FST_Normals, Sampler_NoFilter);
  FModelsPBRProgramLightPass.SetUniform('Rg_AO_Mtl', FST_Material, Sampler_NoFilter);
  FModelsPBRProgramLightPass.SetUniform('Depth', FST_Depth, Sampler_NoFilter);
  FModelsPBRProgramLightPass.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);

 //draw non depth objects
  Main.States.Blending[0] := True;
  Main.States.DepthWrite := False;
  FGBufferForTransparent.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FGBufferForTransparent.Select();

 //draw cubemap if needed
  if not FEnviromentAsColor then
  begin
    Main.States.DepthFunc := cfGreaterEqual;
    FCubeDrawProgram.Select();
    FCubeDrawProgram.SetUniform('uDepthRange', Main.Projection.DepthRange.y);
    FCubeDrawProgram.SetUniform('Cube', FEnviromentCube.Radiance, Sampler_Linear);
    FCubeDrawProgram.SetUniform('uSampleLevel', 1.2);
    FCubeDrawProgram.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);
    Main.States.DepthFunc := cfGreater;
  end;

 //transparency pass
  UpdateAllModels(mtTransparent);
  if FAllModels.Count > 0 then
  begin
    SelectProgramForLighting(FModelsPBRProgram);
    FModels.Select;
    FModels.Draw(FAllModels);
  end;

 //callback
  if Assigned(FOnAfterDraw) then
    FOnAfterDraw(Self);

 //graphical objects
  FGObjs.Reset;
  while FGObjs.Next(gobj) do gobj.Draw();

 //emission objects
  UpdateAllModels(mtEmissive);

  Main.States.DepthFunc := cfGreaterEqual;
  FEmissionFBO.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FEmissionFBO.Select();
  FEmissionFBO.Clear(0, Vec(0,0,0,0));
  if FAllModels.Count > 0 then
  begin
    FModelsEmissionProgram.Select();
    FModels.Select;
    FModels.Draw(FAllModels);
  end;
  Main.States.DepthFunc := cfGreater;

  Main.States.DepthWrite := True;

  FPostProcess.DoComposeOnly(FGBufferForLightPass, FEmissionFBO);
  FPostProcess.ResultFBO.BlitToWindow();
end;

function TbWorldRenderer.CreatePointLight(): IavPointLight;
begin
  Result := FLightRenderer.AddPointLight();
end;

function TbWorldRenderer.CreateSpotLight(): IavSpotLight;
begin
  Result := FLightRenderer.AddSpotLight();
end;

function TbWorldRenderer.FindPrefabInstances(const AName: string): IavMeshInstance;
begin
  if not FPrefabs.TryGetValue(AName, Result) then Result := nil;
end;

function TbWorldRenderer.CreateModelInstances(const ANames: array of string): IavModelInstanceArr;
var
  i: Integer;
begin
  Result := TavModelInstanceArr.Create();
  Result.Capacity := Length(ANames);
  for i := Low(ANames) to High(ANames) do
  begin
    Result.Add( FModels.ObtainModel(FPrefabs[ANames[i]].Clone(IntToStr(gvCounter))) );
    Inc(gvCounter);
  end;
end;

function TbWorldRenderer.Particles: TbParticleSystem;
begin
  Result := FParticles;
end;

procedure TbWorldRenderer.PreloadModels(const AFiles: array of string);
var
  i: Integer;
  newPrefabs: IavMeshInstances;
  inst_name: string;
  inst: IavMeshInstance;
  remapFile: string;
  remapper: IMeshLoaderCallback;
begin
  for i := Low(AFiles) to High(AFiles) do
  begin
    remapFile := AFiles[i]+'.texremap';
    if FileExists(remapFile) then
      remapper := TTexRemapper.Create(remapFile)
    else
      remapper := nil;

    newPrefabs := LoadInstancesFromFile(AFiles[i], nil, remapper);
    newPrefabs.Reset;
    while newPrefabs.Next(inst_name, inst) do
      FPrefabs.Add(inst_name, inst);
  end;
end;

procedure TbWorldRenderer.SetEnviromentAmbient(const AAmbientColor: TVec3);
begin
  FEnviromentAmbient := AAmbientColor;
  FEnviromentAsColor := True;
end;

procedure TbWorldRenderer.SetEnviromentCubemap(const AFileName: string);
begin
  if AFileName = '' then Exit;
  FEnviromentAsColor := False;
  FEnviromentFile := AFileName;
end;

{ TbGameObject }

procedure TbGameObject.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
  InvalidateTransform;
  UpdateAtTree;
end;

procedure TbGameObject.SetBBox(const AValue: TAABB);
begin
  if FBBox = AValue then Exit;
  FBBox := AValue;
  UpdateAtTree;
end;

procedure TbGameObject.SetRot(const AValue: TQuat);
begin
  if FRot = AValue then Exit;
  FRot := AValue;
  InvalidateTransform;
  UpdateAtTree;
end;

procedure TbGameObject.SetScale(const AValue: Single);
begin
  if FScale = AValue then Exit;
  FScale := AValue;
  InvalidateTransform;
end;

procedure TbGameObject.SetStatic(const AValue: Boolean);
begin
  if FStatic = AValue then Exit;
  FStatic := AValue;
end;

function TbGameObject.GetStatic: Boolean;
begin
  Result := FStatic or (not FSubscribed);
end;

procedure TbGameObject.UpdateAtTree;
begin
  FWorld.FTree.Delete(Self);
  if not FBBox.IsEmpty then
    FWorld.FTreeToAdd.Add(Self)
  else
    FWorld.FTreeToAdd.Delete(Self);
end;

procedure TbGameObject.ValidateTransform;
var i: Integer;
begin
  if FTransformValid then Exit;
  FTransformValid := True;
  FTransform := MatScale(Vec(FScale, FScale, FScale)) * Mat4(Rot, Pos);
  FTransformInv := Inv(FTransform);

  for i := 0 to FModels.Count - 1 do
    FModels[i].Transform := FTransform;
  for i := 0 to FEmissive.Count - 1 do
    FEmissive[i].Transform := FTransform;
  for i := 0 to FTransparent.Count - 1 do
    FTransparent[i].Transform := FTransform;

  FWorld.FRenderer.FLightRenderer.InvalidateShadowsAt(AbsBBox());

  AfterValidateTransform;
end;

procedure TbGameObject.AfterValidateTransform;
begin

end;

procedure TbGameObject.InvalidateTransform;
begin
  if FTransformValid then
    FWorld.FRenderer.FLightRenderer.InvalidateShadowsAt(AbsBBox());
  FTransformValid := False;
end;

function TbGameObject.GetPos: TVec3;
begin
  Result := FPos;
end;

function TbGameObject.GetRot: TQuat;
begin
  Result := FRot;
end;

procedure TbGameObject.SubscribeForUpdateStep(const ASubscribeDuration: Integer);
begin
  FWorld.FUpdateSubs.Add(Self);
  FSubscribed := True;
  if ASubscribeDuration > 0 then
    FUnsubscribeTime := FWorld.GameTime + ASubscribeDuration
  else
    FUnsubscribeTime := -1;
end;

procedure TbGameObject.UnSubscribeFromUpdateStep;
begin
  FWorld.FUpdateSubs.Delete(Self);
  FSubscribed := False;
end;

procedure TbGameObject.UpdateStep;
begin
  if FUnsubscribeTime > 0 then
    if FWorld.GameTime > FUnsubscribeTime then
      UnSubscribeFromUpdateStep;
end;

procedure TbGameObject.RegisterAsUIObject;
begin
  World.FUIObjects.AddOrSet(Self);
end;

procedure TbGameObject.UnRegisterAsUIObject;
begin
  World.FUIObjects.Delete(Self);
end;

function TbGameObject.CanRegister(target: TavObject): boolean;
begin
  Result := inherited CanRegister(target);
  if not Result then Exit;
  FWorld := TbWorld(target.FindAtParents(TbWorld));
  Result := Assigned(FWorld);
end;

procedure TbGameObject.ClearModels(AType: TModelType);
begin
  case AType of
    mtDefault : FModels.Clear();
    mtEmissive : FEmissive.Clear();
    mtTransparent : FTransparent.Clear();
  end;
end;

procedure TbGameObject.WriteModels(const ACollection: IavModelInstanceArr; AType: TModelType);
begin
  ValidateTransform;
  case AType of
    mtDefault : ACollection.AddArray(FModels);
    mtEmissive : ACollection.AddArray(FEmissive);
    mtTransparent : ACollection.AddArray(FTransparent);
  end;
end;

procedure TbGameObject.WriteDepthOverrideModels(
  const ACollection: IavModelInstanceArr;
  const ADepthOverride: IOverrideColorArr);
begin

end;

procedure TbGameObject.WriteParticles(const ACollection: IParticlesHandleArr);
begin

end;

function TbGameObject.UIIndex: Integer;
begin
  Result := 0;
end;

procedure TbGameObject.UIDraw();
begin

end;

function TbGameObject.Transform(): TMat4;
begin
  ValidateTransform;
  Result := FTransform;
end;

function TbGameObject.TransformInv(): TMat4;
begin
  ValidateTransform;
  Result := FTransformInv;
end;

function TbGameObject.AbsBBox(): TAABB;
begin
  Result := BBox * Transform();
end;

function TbGameObject.GetVisible(): Boolean;
begin
  Result := True;
end;

procedure TbGameObject.AddModel(const AName: string; AType: TModelType);
var inst: IavModelInstanceArr;
begin
  inst := World.Renderer.CreateModelInstances([AName]);
  inst[0].Transform := Transform();
  case AType of
    mtDefault:
      begin
        FModels.Add(inst[0]);
      end;
    mtEmissive:
      begin
        FEmissive.Add(inst[0]);
      end;
    mtTransparent:
      begin
        FTransparent.Add(inst[0]);
      end;
  end;
end;

procedure TbGameObject.AfterConstruction;
begin
  inherited AfterConstruction;

  FWorld.FObjects.Add(Self);

  FModels := TavModelInstanceArr.Create;
  FEmissive := TavModelInstanceArr.Create;
  FTransparent := TavModelInstanceArr.Create;

  UpdateAtTree;
end;

constructor TbGameObject.Create(AParent: TavObject);
begin
  FScale := 1;
  FRot.v4 := Vec(0,0,0,1);
  inherited Create(AParent);
end;

destructor TbGameObject.Destroy;
begin
  if FWorld <> nil then
  begin
    FWorld.FTree.Delete(Self);
    FWorld.FTreeToAdd.Delete(Self);

    FWorld.FObjects.Delete(Self);
    FWorld.FToDestroy.Delete(Self);
    FWorld.FUpdateSubs.Delete(Self);
    FWorld.FUIObjects.Delete(Self);
    if FWorld.WorldState = Self then
      FWorld.WorldState := nil;
  end;
  inherited Destroy;
end;

{ TbWorld }

procedure TbWorld.SetWorldState(const AValue: TbGameObject);
begin
  if FWorldState = AValue then Exit;
  FWorldState := AValue;
end;

procedure TbWorld.Process_TreeToAdd;
var obj: TbGameObject;
begin
  if FTreeToAdd.Count = 0 then Exit;
  FTreeToAdd.Reset;
  while FTreeToAdd.Next(obj) do
    FTree.Add(obj, obj.AbsBBox());
  FTreeToAdd.Clear;
end;

function TbWorld.GetGameTime: Int64;
begin
  Result := FTimeTick * Main.UpdateStatesInterval;
end;

function TbWorld.QueryObjects(const AViewProj: TMat4): IbGameObjArr;
var it: ILooseNodeCallBackIterator;
begin
  Process_TreeToAdd;

  Result := TbGameObjArr.Create();
  it := TTree_Iterator.Create(Result, AViewProj, Main.Projection.DepthRange);
  FTree.EnumNodes(it);
end;

function TbWorld.QueryObjects(const ABox: TAABB): IbGameObjArr;
var it: ILooseNodeCallBackIterator;
begin
  Process_TreeToAdd;

  Result := TbGameObjArr.Create();
  it := TTree_Iterator.Create(Result, ABox);
  FTree.EnumNodes(it);
end;

function TbWorld.QueryObjects(const ARay: TLine): IbGameObjArr;
begin
  //todo
  Assert(False);
  Result := nil;
end;

function TbWorld.UIObjects: IbGameObjSet;
begin
  Result := FUIObjects;
end;

procedure TbWorld.UpdateStep(AStepCount: Integer = 1);
var
  obj: TbGameObject;
  gobjs_all: IbGraphicalObjectSet;
  gobj: TbGraphicalObject;
  i: Integer;
begin
  Inc(FTimeTick, AStepCount);
  ProcessToDestroy;

  gobjs_all := FRenderer.GraphicalObjects;
  gobjs_all.Reset;
  while gobjs_all.Next(gobj) do
  begin
    gobj.UpdateStep;
    if gobj.MarkedForDestroy then FGObjsToDestroy.Add(gobj);
  end;
  for i := 0 to FGObjsToDestroy.Count - 1 do
    FGObjsToDestroy[i].Free;
  FGObjsToDestroy.Clear();

  FTempObjs.Clear;
  FUpdateSubs.Reset;
  while FUpdateSubs.Next(obj) do
    FTempObjs.Add(obj);
  for i := 0 to FTempObjs.Count - 1 do
    FTempObjs[i].UpdateStep;
  FColliders.UpdateStep(Main.UpdateStatesInterval * AStepCount);
  //FPhysics.UpdateStep(Main.UpdateStatesInterval);
end;

procedure TbWorld.SafeDestroy(const AObj: TbGameObject);
begin
  FToDestroy.AddOrSet(AObj);
end;

procedure TbWorld.ProcessToDestroy;
var obj : TbGameObject;
    i: Integer;
begin
  FTempObjs.Clear;
  FToDestroy.Reset;
  while FToDestroy.Next(obj) do
    FTempObjs.Add(obj);
  for i := 0 to FTempObjs.Count-1 do
    FTempObjs[i].Free;
  FToDestroy.Clear;
end;

procedure TbWorld.AfterConstruction;
begin
  inherited AfterConstruction;
  FTree := TbGameObjTree.Create(Vec(1,1,1));
  FTreeToAdd := TbGameObjSet.Create();

  FObjects    := TbGameObjSet.Create();
  FToDestroy  := TbGameObjSet.Create();
  FUpdateSubs := TbGameObjSet.Create();
  FTempObjs   := TbGameObjArr.Create();
  FUIObjects  := TbGameObjSet.Create();
  FGObjsToDestroy := TbGraphicalObjectArr.Create();

  FStaticForUpdate := TbGameObjSet.Create();

  FRenderer := TbWorldRenderer.Create(Self);
  //FPhysics := Create_IPhysWorld();
  FColliders := Create_IAutoCollidersGroup();
  FSndPlayer:= GetLightPlayer;
end;

end.

