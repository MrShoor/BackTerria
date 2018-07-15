unit bWorld;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  intfUtils,
  Classes, SysUtils,
  avRes,
  avContnrs,
  mutils,
  bTypes,
  bLights,
  bPostProcess,
  bMiniParticles,
  bBassLight,
  bAutoColliders,
  avBase,
  avTypes,
  avMesh,
  avModel;

{$I bshaders.inc}
{$IfDef FPC}
  {$R 'shaders\shaders.rc'}
{$Else}
  {$R 'shaders\shaders.res'}
{$EndIf}

type
  TbWorld = class;

  TModelType = (mtDefault, mtEmissive, mtTransparent);

  { TbGameObject }

  TbGameObject = class (TavMainRenderChild)
  private
    FBBox: TAABB;

    FPos: TVec3;
    FRot: TQuat;
    FScale: Single;
    FTransformValid: Boolean;
    FTransform: TMat4;
    FTransformInv: TMat4;
  protected
    procedure ValidateTransform; virtual;
    function  GetPos: TVec3; virtual;
    function  GetRot: TQuat; virtual;
    procedure SetBBox(const AValue: TAABB); virtual;
    procedure SetPos(const AValue: TVec3); virtual;
    procedure SetRot(const AValue: TQuat); virtual;
    procedure SetScale(const AValue: Single); virtual;
  protected
    procedure SubscribeForUpdateStep;
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

    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;
  TbGameObjArr = {$IfDef FPC}specialize{$EndIf}TArray<TbGameObject>;
  IbGameObjArr = {$IfDef FPC}specialize{$EndIf}IArray<TbGameObject>;
  TbGameObjSet = {$IfDef FPC}specialize{$EndIf}THashSet<TbGameObject>;
  IbGameObjSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TbGameObject>;
  TbGameObjClass = class of TbGameObject;

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
  { TbWorldRenderer }

  TbWorldRenderer = class (TavMainRenderChild)
  private type
    TShadowPassAdapter = class(TInterfacedObject, IGeometryRenderer)
    private
      FOwner: TbWorldRenderer;
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

    FGBuffer: TavFrameBuffer;
    FEmissionFBO: TavFrameBuffer;

    FModelsProgram: TavProgram;
    FModelsPBRProgram: TavProgram;
    FModelsShadowProgram: TavProgram;
    FModelsEmissionProgram: TavProgram;
    FModels: TavModelCollection;
    FPrefabs: IavMeshInstances;
  protected
    FWorld: TbWorld;
    property World: TbWorld read FWorld;
    function CanRegister(target: TavObject): boolean; override;
    procedure AfterRegister; override;
  protected
    FAllModels: IavModelInstanceArr;
    FAllTransparent: IavModelInstanceArr;
    FAllEmissives: IavModelInstanceArr;
    FVisibleObjects: IbGameObjArr;
    procedure UpdateVisibleObjects;
    procedure UpdateAllModels;
  public
    procedure InvalidateShaders;

    procedure PrepareToDraw;
    procedure DrawWorld;

    function CreatePointLight(): IavPointLight;
    function CreateSpotLight(): IavSpotLight;

    function CreateModelInstances(const ANames: array of string): IavModelInstanceArr;
    function Particles: TbParticleSystem;

    procedure PreloadModels(const AFiles: array of string);
  end;

  { TbWorld }

  TbWorld = class (TavMainRenderChild)
  private
    FObjects   : IbGameObjSet;
    FToDestroy : IbGameObjSet;
    FUpdateSubs: IbGameObjSet;
    FTempObjs  : IbGameObjArr;

    FUIObjects : IbGameObjSet;
    FWorldState: TbGameObject;

    FTimeTick: Int64;

    FRenderer : TbWorldRenderer;
    FColliders: IAutoCollidersGroup;
    //FPhysics  : IPhysWorld;
    FSndPlayer: ILightPlayer;

    function GetGameTime: Int64;
    procedure SetWorldState(const AValue: TbGameObject);
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

    procedure UpdateStep();
    procedure SafeDestroy(const AObj: TbGameObject);
    procedure ProcessToDestroy;

    property WorldState: TbGameObject read FWorldState write SetWorldState;

    procedure AfterConstruction; override;
  end;

implementation

uses avTexLoader;

var gvCounter: Int64;

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
    FDefaultCollider.Pos := AValue + FDefaultColliderOffset;
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

procedure TbWorldRenderer.TShadowPassAdapter.ShadowPassGeometry(
  const ALight: TavLightSource; const ALightData: TLightData);
begin
  FOwner.FModelsShadowProgram.Select;
  FOwner.FModelsShadowProgram.SetUniform('matCount', 6);
  FOwner.FModelsShadowProgram.SetUniform('sliceOffset', Integer(round(ALightData.ShadowSizeSliceRange.y)));
  FOwner.FModelsShadowProgram.SetUniform('viewProj', ALight.Matrices, 6);
  FOwner.FModels.Select;
  FOwner.FModels.Draw(FOwner.FAllModels);
end;

procedure TbWorldRenderer.TShadowPassAdapter.DrawTransparentGeometry;
begin

end;

constructor TbWorldRenderer.TShadowPassAdapter.Create(AOwner: TbWorldRenderer);
begin
  FOwner := AOwner;
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
var tex: TavTexture;
begin
  inherited AfterRegister;
  FLightRenderer := TavLightRenderer.Create(Self);
  FShadowPassAdapter := TShadowPassAdapter.Create(Self);
  FParticles := TbParticleSystem.Create(Self);

  FPostProcess := TavPostProcess.Create(Self);

  //FGBuffer := Create_FrameBuffer(Self, [TTextureFormat.RGBA16f, TTextureFormat.RGBA, TTextureFormat.D32f], [false, false, false]);
  FGBuffer := Create_FrameBuffer(Self, [TTextureFormat.RGBA, TTextureFormat.D32f], [true, false]);
  FEmissionFBO := Create_FrameBuffer(FGBuffer, [TTextureFormat.RGBA16f], [false]);
  (FEmissionFBO.GetColor(0) as TavTexture).AutoGenerateMips := True;
  FEmissionFBO.SetDepth(FGBuffer.GetDepth, 0);

  FModelsProgram := TavProgram.Create(Self);
  FModelsProgram.Load('avMesh', SHADERS_FROMRES, SHADERS_DIR);
  FModelsPBRProgram := TavProgram.Create(Self);
  FModelsPBRProgram.Load('avMeshPBR', SHADERS_FROMRES, SHADERS_DIR);
  FModelsShadowProgram := TavProgram.Create(Self);
  FModelsShadowProgram.Load('avMesh_shadow', SHADERS_FROMRES, SHADERS_DIR);
  FModelsEmissionProgram := TavProgram.Create(Self);
  FModelsEmissionProgram.Load('avMesh_emission', SHADERS_FROMRES, SHADERS_DIR);
  FModels := TavModelCollection.Create(Self);

  FPrefabs := TavMeshInstances.Create();

  FAllModels := TavModelInstanceArr.Create();
  FAllTransparent := TavModelInstanceArr.Create();
  FAllEmissives := TavModelInstanceArr.Create();
  FVisibleObjects := TbGameObjArr.Create();
end;

procedure TbWorldRenderer.UpdateVisibleObjects;
begin
  FVisibleObjects := World.QueryObjects(Main.Camera.Matrix * Main.Projection.Matrix);
end;

procedure TbWorldRenderer.UpdateAllModels;
var
  i: Integer;
begin
  FAllModels.Clear();
  FAllTransparent.Clear();
  FAllEmissives.Clear();
  for i := 0 to FVisibleObjects.Count - 1 do
  begin
    FVisibleObjects[i].WriteModels(FAllModels, mtDefault);
    FVisibleObjects[i].WriteModels(FAllTransparent, mtTransparent);
    FVisibleObjects[i].WriteModels(FAllEmissives, mtEmissive);
  end;
end;

procedure TbWorldRenderer.InvalidateShaders;
begin
  FLightRenderer.InvalidateShaders;
  FPostProcess.InvalidateShaders;
  FModelsProgram.Invalidate;
  FModelsPBRProgram.Invalidate;
  FModelsEmissionProgram.Invalidate;
  FModelsShadowProgram.Invalidate;
end;

procedure TbWorldRenderer.PrepareToDraw;
begin
  UpdateVisibleObjects();
  UpdateAllModels();

  Main.States.DepthTest := True;

  Main.States.CullMode := cmFront;

  FLightRenderer.Render(FShadowPassAdapter);

  FGBuffer.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FGBuffer.Select;
end;

procedure TbWorldRenderer.DrawWorld;
const
    cSampler_Cubes : TSamplerInfo = (
      MinFilter  : tfLinear;
      MagFilter  : tfLinear;
      MipFilter  : tfLinear;
      Anisotropy : 0;
      Wrap_X     : twClamp;
      Wrap_Y     : twClamp;
      Wrap_Z     : twClamp;
      Border     : (x: 0; y: 0; z: 0; w: 0);
      Comparison : cfGreater;
    );
var sCubes: TSamplerInfo;
    prog: TavProgram;
begin
  sCubes := cSampler_Cubes;
  sCubes.Comparison := Main.States.DepthFunc;

  Main.States.CullMode := cmBack;

  if True then
    prog := FModelsPBRProgram
  else
    prog := FModelsProgram;
  prog.Select();
  prog.SetUniform('depthRange', Main.Projection.DepthRange);
  prog.SetUniform('planesNearFar', Vec(Main.Projection.NearPlane, Main.Projection.FarPlane));
  prog.SetUniform('lightCount', FLightRenderer.LightsCount*1.0);
  prog.SetUniform('light_list', FLightRenderer.LightsList);
  prog.SetUniform('light_headBufferSize', FLightRenderer.LightsHeadBuffer.Size*1.0);
  prog.SetUniform('light_headBuffer', FLightRenderer.LightsHeadBuffer, Sampler_NoFilter);
  prog.SetUniform('light_linkedList', FLightRenderer.LightsLinkedList);
  prog.SetUniform('light_matrices', FLightRenderer.LightMatrices);
  prog.SetUniform('ShadowCube512', FLightRenderer.Cubes512, sCubes);
  FModels.Select();

  //depth prepass
  Main.States.ColorMask[AllTargets] := [];
  FModels.Draw(FAllModels);

  //color pass
  Main.States.ColorMask[AllTargets] := AllChanells;
  Main.States.DepthFunc := cfEqual;
  FModels.Draw(FAllModels);
  Main.States.DepthFunc := cfGreater;

  //draw non depth objects
  Main.States.DepthWrite := False;
  //transparent first
  FModels.Draw(FAllTransparent);

  Main.States.DepthFunc := cfGreaterEqual;
  FEmissionFBO.FrameRect := FGBuffer.FrameRect;
  FEmissionFBO.Select();
  FEmissionFBO.Clear(0, Vec(0,0,0,0));
  FModelsEmissionProgram.Select();
  FModels.Select;
  FModels.Draw(FAllEmissives);
  Main.States.DepthFunc := cfGreater;

  Main.States.DepthWrite := True;

  if Main.ActiveApi = apiDX11_WARP then
    FGBuffer.BlitToWindow();

  FPostProcess.DoComposeOnly(FGBuffer, FEmissionFBO);
  FPostProcess.ResultFBO.BlitToWindow();
  {
  if Main.ActiveApi = apiDX11_WARP then //early exit for WARP devices
  begin
    FGBuffer.BlitToWindow();
    Main.States.DepthWrite := True;
    Exit;
  end;

  FPostProcess.DoPostProcess(FGBuffer);

  FPostProcess.ResultFBO.BlitToWindow();
  }
end;

function TbWorldRenderer.CreatePointLight: IavPointLight;
begin
  Result := FLightRenderer.AddPointLight();
end;

function TbWorldRenderer.CreateSpotLight: IavSpotLight;
begin
  Result := FLightRenderer.AddSpotLight();
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
begin
  for i := Low(AFiles) to High(AFiles) do
  begin
    newPrefabs := LoadInstancesFromFile(AFiles[i]);
    newPrefabs.Reset;
    while newPrefabs.Next(inst_name, inst) do
      FPrefabs.Add(inst_name, inst);
  end;
end;

{ TbGameObject }

procedure TbGameObject.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
  FTransformValid := False;
end;

procedure TbGameObject.SetBBox(const AValue: TAABB);
begin
  if FBBox = AValue then Exit;
  FBBox := AValue;
end;

procedure TbGameObject.SetRot(const AValue: TQuat);
begin
  if FRot = AValue then Exit;
  FRot := AValue;
  FTransformValid := False;
end;

procedure TbGameObject.SetScale(const AValue: Single);
begin
  if FScale = AValue then Exit;
  FScale := AValue;
  FTransformValid := False;
end;

procedure TbGameObject.ValidateTransform;
var i: Integer;
begin
  if FTransformValid then Exit;
  FTransform := MatScale(Vec(FScale, FScale, FScale)) * Mat4(Rot, Pos);
  FTransformInv := Inv(FTransform);

  for i := 0 to FModels.Count - 1 do
    FModels[i].Mesh.Transform := FTransform;
  for i := 0 to FEmissive.Count - 1 do
    FEmissive[i].Mesh.Transform := FTransform;
  for i := 0 to FTransparent.Count - 1 do
    FTransparent[i].Mesh.Transform := FTransform;
end;

function TbGameObject.GetPos: TVec3;
begin
  Result := FPos;
end;

function TbGameObject.GetRot: TQuat;
begin
  Result := FRot;
end;

procedure TbGameObject.SubscribeForUpdateStep;
begin
  FWorld.FUpdateSubs.Add(Self);
end;

procedure TbGameObject.UnSubscribeFromUpdateStep;
begin
  FWorld.FUpdateSubs.Delete(Self);
end;

procedure TbGameObject.UpdateStep;
begin
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

procedure TbGameObject.WriteParticles(const ACollection: IParticlesHandleArr);
begin

end;

function TbGameObject.UIIndex: Integer;
begin
  Result := 0;
end;

procedure TbGameObject.UIDraw;
begin

end;

function TbGameObject.Transform: TMat4;
begin
  ValidateTransform;
  Result := FTransform;
end;

function TbGameObject.TransformInv: TMat4;
begin
  ValidateTransform;
  Result := FTransformInv;
end;

procedure TbGameObject.AddModel(const AName: string; AType: TModelType);
var inst: IavModelInstanceArr;
begin
  inst := World.Renderer.CreateModelInstances([AName]);
  inst[0].Mesh.Transform := Transform();
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
  FScale := 1;
  FRot.v4 := Vec(0,0,0,1);
  FBBox := EmptyAABB;

  FWorld.FObjects.Add(Self);

  FModels := TavModelInstanceArr.Create;
  FEmissive := TavModelInstanceArr.Create;
  FTransparent := TavModelInstanceArr.Create;
end;

destructor TbGameObject.Destroy;
begin
  if FWorld <> nil then
  begin
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

function TbWorld.GetGameTime: Int64;
begin
  Result := FTimeTick * Main.UpdateStatesInterval;
end;

function TbWorld.QueryObjects(const AViewProj: TMat4): IbGameObjArr;
var obj: TbGameObject;
begin
  Result := TbGameObjArr.Create();
  FObjects.Reset;
  while FObjects.Next(obj) do
    Result.Add(obj);
end;

function TbWorld.QueryObjects(const ABox: TAABB): IbGameObjArr;
var obj: TbGameObject;
begin
  Result := TbGameObjArr.Create();
  FObjects.Reset;
  while FObjects.Next(obj) do
    Result.Add(obj);
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

procedure TbWorld.UpdateStep;
var
  obj: TbGameObject;
begin
  Inc(FTimeTick);
  ProcessToDestroy;

  FUpdateSubs.Reset;
  while FUpdateSubs.Next(obj) do
    obj.UpdateStep;
  FColliders.UpdateStep;
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
  FObjects    := TbGameObjSet.Create();
  FToDestroy  := TbGameObjSet.Create();
  FUpdateSubs := TbGameObjSet.Create();
  FTempObjs   := TbGameObjArr.Create();
  FUIObjects  := TbGameObjSet.Create();

  FRenderer := TbWorldRenderer.Create(Self);
  //FPhysics := Create_IPhysWorld();
  FColliders := Create_IAutoCollidersGroup();
  FSndPlayer:= GetLightPlayer;
end;

end.

