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
  avBase,
  avTypes,
  avMesh,
  avModel;

const
  SHADERS_FROMRES = False;
  SHADERS_DIR = 'D:\Projects\BackTerria\Src\shaders\!Out';

type
  TbWorld = class;

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

    procedure SetBBox(const AValue: TAABB);
    procedure SetPos(const AValue: TVec3);
    procedure SetRot(const AValue: TQuat);
    procedure SetScale(const AValue: Single);

    procedure ValidateTransform;
  protected
    procedure SubscribeForUpdateStep;
    procedure UnSubscribeFromUpdateStep;
    procedure UpdateStep; virtual;
  protected
    FWorld: TbWorld;
    function CanRegister(target: TavObject): boolean; override;
  public
    property World: TbWorld read FWorld;

    procedure WriteModels(const ACollection: IavModelInstanceArr); virtual;

    property Pos  : TVec3  read FPos   write SetPos;
    property Rot  : TQuat  read FRot   write SetRot;
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

  { TbStaticObject }

  TbStaticObject = class (TbGameObject)
  private
  protected
    FModels: IavModelInstanceArr;
  public
    procedure WriteModels(const ACollection: IavModelInstanceArr); override;
    procedure AddModel(const AName: string);

    procedure AfterConstruction; override;
  end;

  { TbWorldRenderer }

  TbWorldRenderer = class (TavMainRenderChild)
  private type
    TShadowPassAdapter = class(TInterfacedObject, IGeometryRenderer)
    private
      FOwner: TbWorldRenderer;
      procedure ShadowPassGeometry(const ALight: TLightData; const APointLightMatrices: TPointLightMatrices);
      procedure DrawTransparentGeometry();
    public
      constructor Create(AOwner: TbWorldRenderer);
    end;
  private
    FLightRenderer: TavLightRenderer;
    FShadowPassAdapter: IGeometryRenderer;
    FPostProcess: TavPostProcess;

    FGBuffer: TavFrameBuffer;

    FModelsProgram: TavProgram;
    FModelsShadowProgram: TavProgram;
    FModels: TavModelCollection;
    FPrefabs: IavMeshInstances;
  protected
    FWorld: TbWorld;
    property World: TbWorld read FWorld;
    function CanRegister(target: TavObject): boolean; override;
    procedure AfterRegister; override;
  protected
    FAllModels: IavModelInstanceArr;
    FVisibleObjects: IbGameObjArr;
    procedure UpdateVisibleObjects;
    procedure UpdateAllModels;
  public
    procedure InvalidateShaders;

    procedure PrepareToDraw;
    procedure DrawWorld;

    function CreatePointLight(): TavPointLight;
    function CreateModelInstances(const ANames: array of string): IavModelInstanceArr;

    procedure PreloadModels(const AFiles: array of string);
  end;

  { TbWorld }

  TbWorld = class (TavMainRenderChild)
  private
    FObjects   : IbGameObjSet;
    FToDestroy : IbGameObjSet;
    FUpdateSubs: IbGameObjSet;
    FTempObjs  : IbGameObjArr;

    FTimeTick: Int64;

    FRenderer : TbWorldRenderer;
  public
    property Renderer: TbWorldRenderer read FRenderer;

    function QueryObjects(const AViewProj: TMat4): IbGameObjArr; overload;
    function QueryObjects(const ABox: TAABB): IbGameObjArr; overload;
    function QueryObjects(const ARay: TLine): IbGameObjArr; overload;

    property GameTime: Int64 read FTimeTick;

    procedure UpdateStep();
    procedure SafeDestroy(const AObj: TbGameObject);
    procedure ProcessToDestroy;

    procedure AfterConstruction; override;
  end;

implementation

{ TbWorldRenderer.TShadowPassAdapter }

procedure TbWorldRenderer.TShadowPassAdapter.ShadowPassGeometry(
  const ALight: TLightData; const APointLightMatrices: TPointLightMatrices);
begin
  FOwner.FModelsShadowProgram.Select;
  FOwner.FModelsShadowProgram.SetUniform('matCount', 6);
  FOwner.FModelsShadowProgram.SetUniform('viewProj', @APointLightMatrices.viewProj[0], 6);
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

{ TbStaticObject }

procedure TbStaticObject.WriteModels(const ACollection: IavModelInstanceArr);
begin
  inherited WriteModels(ACollection);
  ACollection.AddArray(FModels);
end;

procedure TbStaticObject.AddModel(const AName: string);
begin
  FModels.AddArray( World.Renderer.CreateModelInstances([AName]) );
  FModels.Last.Mesh.Transform := IdentityMat4;
end;

procedure TbStaticObject.AfterConstruction;
begin
  inherited AfterConstruction;
  FModels := TavModelInstanceArr.Create();
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
begin
  inherited AfterRegister;
  FLightRenderer := TavLightRenderer.Create(Self);
  FShadowPassAdapter := TShadowPassAdapter.Create(Self);

  FPostProcess := TavPostProcess.Create(Self);

  FGBuffer := Create_FrameBuffer(Self, [TTextureFormat.RGBA, TTextureFormat.RGBA, TTextureFormat.D32f], [true, false, false]);

  FModelsProgram := TavProgram.Create(Self);
  FModelsProgram.Load('avMesh', SHADERS_FROMRES, SHADERS_DIR);
  FModelsShadowProgram := TavProgram.Create(Self);
  FModelsShadowProgram.Load('avMesh_shadow', SHADERS_FROMRES, SHADERS_DIR);
  FModels := TavModelCollection.Create(Self);

  FPrefabs := TavMeshInstances.Create();

  FAllModels := TavModelInstanceArr.Create();
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
  for i := 0 to FVisibleObjects.Count - 1 do
    FVisibleObjects[i].WriteModels(FAllModels);
end;

procedure TbWorldRenderer.InvalidateShaders;
begin
  FLightRenderer.InvalidateShaders;
  FPostProcess.InvalidateShaders;
  FModelsProgram.Invalidate;
  FModelsShadowProgram.Invalidate;
end;

procedure TbWorldRenderer.PrepareToDraw;
begin
  UpdateVisibleObjects();
  UpdateAllModels();
end;

procedure TbWorldRenderer.DrawWorld;
const
    Sampler_Cubes : TSamplerInfo = (
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
begin
  Main.States.DepthTest := True;

  Main.States.CullMode := cmFront;

  FLightRenderer.Render(FShadowPassAdapter);

  FGBuffer.FrameRect := RectI(Vec(0,0),Main.WindowSize);
  FGBuffer.Select;
  Main.Clear(Vec(0.0,0.2,0.4,1.0), True, Main.Projection.DepthRange.y, True);

  Main.States.CullMode := cmBack;

  FModelsProgram.Select();
  FModelsProgram.SetUniform('depthRange', Main.Projection.DepthRange);
  FModelsProgram.SetUniform('planesNearFar', Vec(Main.Projection.NearPlane, Main.Projection.FarPlane));
  FModelsProgram.SetUniform('lightCount', FLightRenderer.LightsCount*1.0);
  FModelsProgram.SetUniform('light_list', FLightRenderer.LightsList);
  FModelsProgram.SetUniform('light_headBufferSize', FLightRenderer.LightsHeadBuffer.Size*1.0);
  FModelsProgram.SetUniform('light_headBuffer', FLightRenderer.LightsHeadBuffer, Sampler_NoFilter);
  FModelsProgram.SetUniform('light_linkedList', FLightRenderer.LightsLinkedList);
  FModelsProgram.SetUniform('ShadowCube512', FLightRenderer.Cubes512, Sampler_Cubes);
  FModelsProgram.SetUniform('CubeMatrices', FLightRenderer.LightMatrices);
  FModels.Select();
  FModels.Draw(FAllModels);

  FPostProcess.DoPostProcess(FGBuffer.GetColor(0), FGBuffer.GetColor(1), FGBuffer.GetDepth);

  FPostProcess.ResultFBO.BlitToWindow();
end;

function TbWorldRenderer.CreatePointLight: TavPointLight;
begin
  Result := FLightRenderer.AddPointLight();
end;

function TbWorldRenderer.CreateModelInstances(const ANames: array of string): IavModelInstanceArr;
var
  i: Integer;
begin
  Result := TavModelInstanceArr.Create();
  Result.Capacity := Length(ANames);
  for i := Low(ANames) to High(ANames) do
    Result.Add( FModels.ObtainModel(FPrefabs[ANames[i]]) );
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
begin
  if FTransformValid then Exit;
  FTransform := MatScale(Vec(FScale, FScale, FScale)) * Mat4(FRot, FPos);
  FTransformInv := Inv(FTransform);
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

function TbGameObject.CanRegister(target: TavObject): boolean;
begin
  Result := inherited CanRegister(target);
  if not Result then Exit;
  FWorld := TbWorld(target.FindAtParents(TbWorld));
  Result := Assigned(FWorld);
end;

procedure TbGameObject.WriteModels(const ACollection: IavModelInstanceArr);
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

procedure TbGameObject.AfterConstruction;
begin
  inherited AfterConstruction;
  FScale := 1;
  FRot.v4 := Vec(0,0,0,1);
  FBBox := EmptyAABB;

  FWorld.FObjects.Add(Self);
end;

destructor TbGameObject.Destroy;
begin
  if FWorld <> nil then
  begin
    FWorld.FObjects.Delete(Self);
    FWorld.FToDestroy.Delete(Self);
    FWorld.FUpdateSubs.Delete(Self);
  end;
  inherited Destroy;
end;

{ TbWorld }

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

procedure TbWorld.UpdateStep;
var
  obj: TbGameObject;
begin
  Inc(FTimeTick);
  ProcessToDestroy;

  FUpdateSubs.Reset;
  while FUpdateSubs.Next(obj) do
    obj.UpdateStep;
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

  FRenderer := TbWorldRenderer.Create(Self);
end;

end.

