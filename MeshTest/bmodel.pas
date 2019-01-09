unit bModel;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, bMesh,
  avTypes, avBase, avTess, avRes, avContnrs, avContnrsDefaults,
  mutils;

const
  KeyFrameDuration = 1000/30;
  Default_GrowSpeed = 70;
  Default_FadeSpeed = 70;

type
  IBones = interface (IVerticesData)
    function Matrices: TMat4Arr;
  end;

  IbModelInstance = interface
    procedure GetModelHandles(out vert     : IVBManagedHandle;
                              out ind      : IIBManagedHandle);
    procedure GetBonesOffset(out ABonesOffset: Integer);
    procedure GetMaterialsOffset(out AMaterialsOffset: Integer);

    function Bones: IBones;
    function TexSize: TVec2i;
    function MeshInstnace: IbMeshInstance;

    procedure InvalidateBonesData;
  end;
  IbModelInstanceArr = {$IfDef FPC}specialize{$EndIf} IArray<IbModelInstance>;
  TbModelInstanceArr = {$IfDef FPC}specialize{$EndIf} TArray<IbModelInstance>;
  IbModelInstanceSet = {$IfDef FPC}specialize{$EndIf} IHashSet<IbModelInstance>;
  TbModelInstanceSet = {$IfDef FPC}specialize{$EndIf} THashSet<IbModelInstance>;

  IbAnimationController = interface
    procedure SetTime(const ATime: Int64; const AIncomingEvents: IAnimationEventArr = nil);

    function Contains(const AModelInstance: IbModelInstance): Boolean;
    procedure AddModel(const AModelInstance: IbModelInstance);
    procedure DelModel(const AModelInstance: IbModelInstance);

    procedure BoneAnimationSequence(const AAnimations: array of string; ALoopedLast: Boolean; GrowSpeed: Integer = Default_FadeSpeed; FadeSpeed: Integer = Default_FadeSpeed);
  end;

  { TbModelColleciton }

  TbModelColleciton = class(TavMainRenderChild)
  private type
    TMapIndices = array [TbMeshMaterialTextureKind] of Integer;

    TMaterialVertex = packed record
      Diff: TVec4;
      Spec: TVec4;
      Hardness_IOR_EmitFactor: TVec4;
      map: array [TbMeshMaterialTextureKind] of TVec2;
      procedure Init(const AMaterial: IbMeshMaterial; const AMapIndices: TMapIndices);
      class function Layout: IDataLayout; static;
    end;
    IMaterialVertexArr = {$IfDef FPC}specialize{$EndIf} IArray<TMaterialVertex>;
    TMaterialVertexArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TMaterialVertex>;

    TBones = class (TInterfacedObject, IBones)
    private
      FMatrices: TMat4Arr;
      function VerticesCount: Integer;
      function Layout: IDataLayout;
      function Data: TPointerData;
      function Matrices: TMat4Arr;
    public
      constructor Create(ASize: Integer);
    end;

    IbModel = interface
      procedure GetHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle);
      procedure GetMaterialsOffset(out AMaterialsOffset: Integer);
    end;

    TbModel = class(TInterfacedObject, IbModel)
    private
      FOwner: TbModelColleciton;
      FMesh : IbMesh;
      FVert : IVBManagedHandle;
      FInd  : IIBManagedHandle;

      FMaterials: ISBManagedHandle;

      FMaps : IMTManagedHandleArr;
      procedure GetHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle);
      procedure GetMaterialsOffset(out AMaterialsOffset: Integer);
    public
      procedure Detach;
      constructor Create(AOwner: TbModelColleciton; const AMesh: IbMesh);
      destructor Destroy; override;
    end;
    IbModelObjArr = {$IfDef FPC}specialize{$EndIf} IArray<TbModel>;
    TbModelObjArr = {$IfDef FPC}specialize{$EndIf} TArray<TbModel>;
    IbMeshToModelObjMap = {$IfDef FPC}specialize{$EndIf} IHashMap<IbMesh, TbModel>;
    TbMeshToModelObjMap = {$IfDef FPC}specialize{$EndIf} THashMap<IbMesh, TbModel>;

    { TbModelInstance }

    TbModelInstance = class(TInterfacedObject, IbModelInstance)
    private
      FOwner: TbModelColleciton;
      FIdx  : Integer;

      FMeshInstance: IbMeshInstance;
      FModel: IbModel;

      FTexSize: TVec2i;

      FBns  : ISBManagedHandle;
      FBonesData: IBones;
      procedure GetModelHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle);
      procedure GetBonesOffset(out ABonesOffset: Integer);
      procedure GetMaterialsOffset(out AMaterialsOffset: Integer);

      function Bones: IBones;
      function TexSize: TVec2i;
      function MeshInstnace: IbMeshInstance;

      procedure InvalidateBonesData;
    public
      procedure Detach;
      constructor Create(AOwner: TbModelColleciton; const AMeshInstance: IbMeshInstance);
      destructor Destroy; override;
    end;
    IbModelInstanceObjArr = {$IfDef FPC}specialize{$EndIf} IArray<TbModelInstance>;
    TbModelInstanceObjArr = {$IfDef FPC}specialize{$EndIf} TArray<TbModelInstance>;

    TModelInstanceVertex = packed record
      BoneOffset: Integer;
      MaterialOffset: Integer;
      class function Layout: IDataLayout; static;
    end;
    IModelInstanceVertexArr = {$IfDef FPC}specialize{$EndIf} IArray<TModelInstanceVertex>;
    TModelInstanceVertexArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TModelInstanceVertex>;

    IMultiTextureMap = {$IfDef FPC}specialize{$EndIf} IHashMap<TVec2i, TavMultiTexture>;
    TMultiTextureMap = {$IfDef FPC}specialize{$EndIf} THashMap<TVec2i, TavMultiTexture>;

    TDrawComparer = class (TInterfacedObject, IComparer)
    private
      function Compare(const Left, Right): Integer;
    end;

    TDrawChunk = record
      TexSize : TVec2i;
      InstanceOffset: Integer;
      InstanceCount : Integer;
    end;
    IDrawChunkArr = {$IfDef FPC}specialize{$EndIf} IArray<TDrawChunk>;
    TDrawChunkArr = {$IfDef FPC}specialize{$EndIf} TArray<TDrawChunk>;
  private
    FMeshToModelMap: IbMeshToModelObjMap;
    FModelInstances: IbModelInstanceObjArr;

    FVerts    : TavVBManaged;
    FInds     : TavIBManaged;
    FBones    : TavSBManaged;
    FMaterials: TavSBManaged;

    FInstBufferData: IModelInstanceVertexArr;
    FInstBuffer: TavVB;

    FMaps: IMultiTextureMap;

    FToDraw: IbModelInstanceArr;
    FDrawComparer: IComparer;
    FDrawChunks: IDrawChunkArr;

    function ObtainModel(const AMesh: IbMesh): TbModel;
    function ObtainMultiTexture(const ASize: TVec2i): TavMultiTexture;
  public
    function CreateModel(const AMeshInstance: IbMeshInstance): IbModelInstance;
    function CreateModels(const AMeshInstanceArr: IbMeshInstanceArr): IbModelInstanceArr;

    procedure SubmitBufferClear();
    procedure SubmitToDraw(const AModel: IbModelInstance); overload;
    procedure SubmitToDraw(const AModelArr: IbModelInstanceArr); overload;
    procedure Draw();

    constructor Create(AOwner: TavObject); override;
    destructor Destroy; override;
  end;

function Create_bAnimationController(const AModel: IbModelInstance): IbAnimationController; overload;
function Create_bAnimationController(const AModels: IbModelInstanceArr): IbAnimationController; overload;

implementation

uses
  Math;

type
  { TbAnimationController }

  TbAnimationController = class(TInterfacedObject, IbAnimationController)
  private type
    TAnimationPlayState = packed record
      AnimIndex: Integer;
      Start: Int64;
      Stop : Int64;
      GrowSpeed: Integer;
      FadeSpeed: Integer;
      KeepAtLastFrame: Boolean;
    end;
    PAnimationPlayState = ^TAnimationPlayState;
    IAnimationPlayStateArr = {$IfDef FPC}specialize{$EndIf} IArray<TAnimationPlayState>;
    TAnimationPlayStateArr = {$IfDef FPC}specialize{$EndIf} TArray<TAnimationPlayState>;

    IAnimIndices = {$IfDef FPC}specialize{$EndIf} IArray<Integer>;
    TAnimIndices = {$IfDef FPC}specialize{$EndIf} TArray<Integer>;
  private
    FTime: Int64;

    FArmature: IbArmature;
    FArmatureTransform: TMat4Arr;

    FModels: IbModelInstanceArr;

    FPlayState : IAnimationPlayStateArr;
    FFrameState: array of TAnimationFrame;

    FAnimIdx: IAnimIndices;

    function TimeToFrameFloat(const ATimeFromStart: Int64): Single;
    function TimeToFrame(const ATimeFromStart: Int64): Integer;
    procedure SetTime(const ATime: Int64; const AIncomingEvents: IAnimationEventArr = nil);
    procedure UpdateFrameState;

    function  Contains(const AModelInstance: IbModelInstance): Boolean;
    procedure AddModel(const AModelInstance: IbModelInstance);
    procedure DelModel(const AModelInstance: IbModelInstance);

    procedure StopBoneAnimation(AIndex: Integer; FadeSpeed: Integer = Default_FadeSpeed);
    procedure BoneAnimationSequence(const AAnimations: array of string; ALoopedLast: Boolean; GrowSpeed: Integer = Default_FadeSpeed; FadeSpeed: Integer = Default_FadeSpeed);
  public
    constructor Create(const AModels: IbModelInstanceArr);
  end;

function Create_bAnimationController(const AModel: IbModelInstance): IbAnimationController;
var models: IbModelInstanceArr;
begin
  models := TbModelInstanceArr.Create();
  models.Add(AModel);
  Result := Create_bAnimationController(models);
end;

function Create_bAnimationController(const AModels: IbModelInstanceArr): IbAnimationController;
begin
  Result := TbAnimationController.Create(AModels);
end;

{ TbModelColleciton.TDrawComparer }

function TbModelColleciton.TDrawComparer.Compare(const Left, Right): Integer;
const cMaxTexWidth = 1024 * 1024;
var L: IbModelInstance absolute Left;
    R: IbModelInstance absolute Right;
    ResultNative: NativeInt;
    lSize, rSize: TVec2i;
begin
  lSize := L.TexSize;
  rSize := R.TexSize;
  Result := (lSize.y * cMaxTexWidth + lSize.x) - (rSize.y * cMaxTexWidth + rSize.x);
  if Result = 0 then
  begin
    ResultNative := NativeInt(L.MeshInstnace.Mesh) - NativeInt(R.MeshInstnace.Mesh);
    if ResultNative = 0 then
    begin
      ResultNative := NativeInt(L) - NativeInt(R);
      Result := Sign(ResultNative);
    end
    else
      Result := Sign(ResultNative);
  end;
end;

{ TbModelColleciton.TMaterialVertex }

procedure TbModelColleciton.TMaterialVertex.Init(const AMaterial: IbMeshMaterial; const AMapIndices: TMapIndices);
var
  mInfo: PbMeshMaterialInfo;
  tk: TbMeshMaterialTextureKind;
begin
  mInfo := AMaterial.matInfo;
  Diff := mInfo^.matDiff;
  Spec := mInfo^.matSpec;
  Hardness_IOR_EmitFactor := Vec(mInfo^.matSpecHardness, mInfo^.matSpecIOR, mInfo^.matEmitFactor, 0);
  for tk := Low(TbMeshMaterialTextureKind) to High(TbMeshMaterialTextureKind) do
  begin
    if AMapIndices[tk] < 0 then
      map[tk] := Vec(0, 0)
    else
    begin
      map[tk].x := AMapIndices[tk];
      map[tk].y := mInfo^.Textures[tk].factor;
    end;
  end;
end;

class function TbModelColleciton.TMaterialVertex.Layout: IDataLayout;
begin
  Result := LB.Add('Diff', ctFloat, 4)
              .Add('Spec', ctFloat, 4)
              .Add('Hardness_IOR_EmitFactor', ctFloat, 4)
              .Add('mapDiffuse_Intensity', ctFloat, 2)
              .Add('mapDiffuse_Color', ctFloat, 2)
              .Add('mapDiffuse_Alpha', ctFloat, 2)
              .Add('mapDiffuse_Translucency', ctFloat, 2)
              .Add('mapShading_Ambient', ctFloat, 2)
              .Add('mapShading_Emit', ctFloat, 2)
              .Add('mapShading_Mirror', ctFloat, 2)
              .Add('mapShading_RayMirror', ctFloat, 2)
              .Add('mapSpecular_Intensity', ctFloat, 2)
              .Add('mapSpecular_Color', ctFloat, 2)
              .Add('mapSpecular_Hardness', ctFloat, 2)
              .Add('mapGeometry_Normal', ctFloat, 2)
              .Add('mapGeometry_Warp', ctFloat, 2)
              .Add('mapGeometry_Displace', ctFloat, 2)
              .Finish();
end;

{ TbModelColleciton.TbModel }

procedure TbModelColleciton.TbModel.GetHandles(out vert: IVBManagedHandle; out
  ind: IIBManagedHandle);
begin
  vert := FVert;
  ind := FInd;
end;

procedure TbModelColleciton.TbModel.GetMaterialsOffset(out AMaterialsOffset: Integer);
begin
  AMaterialsOffset := FMaterials.Offset;
end;

procedure TbModelColleciton.TbModel.Detach;
begin
  if FOwner = nil then Exit;
  FVert := nil;
  FInd := nil;
  FMaterials := nil;
  FMaps := nil;
  FOwner.FMeshToModelMap.Delete(FMesh);
  FOwner := nil;
end;

constructor TbModelColleciton.TbModel.Create(AOwner: TbModelColleciton; const AMesh: IbMesh);
var materialsData: IMaterialVertexArr;
    matv: TMaterialVertex;
    material: IbMeshMaterial;
    mapIndices: TMapIndices;
    tex: TavMultiTexture;
    texData: ITextureData;
    i: Integer;
    tk: TbMeshMaterialTextureKind;
begin
  FOwner := AOwner;
  FMesh := AMesh;
  FOwner.FMeshToModelMap.Add(FMesh, Self);
  FVert := AOwner.FVerts.Add(FMesh.Vert as IVerticesData);
  FInd := AOwner.FInds.Add(FMesh.Ind);

  FMaps := nil;
  materialsData := TMaterialVertexArr.Create();
  if FMesh.GetMaterialsCount() > 0 then
  begin
    tex := FOwner.ObtainMultiTexture(FMesh.TexturesSize());
    if tex <> nil then
      FMaps := TMTManagedHandleArr.Create();

    materialsData.Capacity := FMesh.GetMaterialsCount();
    for i := 0 to FMesh.GetMaterialsCount() - 1 do
    begin
      for tk := Low(TbMeshMaterialTextureKind) to High(TbMeshMaterialTextureKind) do mapIndices[tk] := -1;
      material := FMesh.GetMaterial(i);
      if tex <> nil then
      begin
        for tk := Low(TbMeshMaterialTextureKind) to High(TbMeshMaterialTextureKind) do
        begin
          texData := material.TexData(tk);
          if texData <> nil then
          begin
            FMaps.Add(tex.Add(texData));
            mapIndices[tk] := FMaps.Last.Offset;
          end;
        end;
      end;
      matv.Init(material, mapIndices);
      materialsData.Add(matv);
    end;
  end
  else
  begin
    materialsData.Capacity := 1;
    ZeroClear(matv, SizeOf(matv));
    matv.Diff := Vec(1,1,1,1);
    matv.Hardness_IOR_EmitFactor := Vec(0.5, 0.5, 0, 0);
    matv.Spec := Vec(1,1,1,1);
    materialsData.Add(matv);
  end;

  FMaterials := FOwner.FMaterials.Add(materialsData as IVerticesData);
end;

destructor TbModelColleciton.TbModel.Destroy;
begin
  Detach;
  inherited Destroy;
end;

{ TbAnimationController }

function TbAnimationController.TimeToFrameFloat(const ATimeFromStart: Int64): Single;
begin
  Result := ATimeFromStart / KeyFrameDuration;
end;

function TbAnimationController.TimeToFrame(const ATimeFromStart: Int64): Integer;
begin
  Result := Floor(TimeToFrameFloat(ATimeFromStart));
end;

procedure TbAnimationController.SetTime(const ATime: Int64; const AIncomingEvents: IAnimationEventArr);

  procedure UpdatePlayState(AOldTime, ANewTime: Integer);
  var ps: TAnimationPlayState;
      anim: IbArmatureAnimation;
      i: LongInt;
  begin
    for i := FPlayState.Count - 1 downto 0 do
    begin
      ps := FPlayState[i];
      if (ps.Stop <= ANewTime) then
      begin
        if AIncomingEvents <> nil then
          if ps.Stop > AOldTime then
          begin
            anim := FArmature.GetAnimation(ps.AnimIndex);
            anim.ProcessMarkers(TimeToFrame(max(AOldTime - ps.Start, 0)), TimeToFrame(ANewTime - ps.Start), AIncomingEvents);
          end;
        if not ps.KeepAtLastFrame then
          FPlayState.DeleteWithSwap(i);
        Continue;
      end
      else
      begin
        if AIncomingEvents <> nil then
          if ps.Start < ANewTime then
          begin
            anim := FArmature.GetAnimation(ps.AnimIndex);
            anim.ProcessMarkers(TimeToFrame(max(AOldTime - ps.Start, 0)), TimeToFrame(ANewTime - ps.Start), AIncomingEvents);
          end;
      end;
    end;
  end;

var
  i: Integer;
  boneMat: TMat4Arr;
begin
  if ATime = FTime then Exit;
  UpdatePlayState(FTime, ATime);
  FTime := ATime;
  UpdateFrameState;

  FArmature.EvalTransform(FFrameState, FArmatureTransform);
  for i := 0 to FModels.Count - 1 do
  begin
    boneMat := FModels[i].Bones.Matrices;
    FModels[i].MeshInstnace.RemapArmatureMatrices(FArmatureTransform, boneMat);
    FModels[i].InvalidateBonesData;
  end;
end;

procedure TbAnimationController.UpdateFrameState;
var i: Integer;
    ps: TAnimationPlayState;
    anim: IbArmatureAnimation;
    animRange: TVec2i;
    fadeWeight, growWeight: Single;
    summWeight: Single;
begin
  if Length(FFrameState) <> FPlayState.Count then
    SetLength(FFrameState, FPlayState.Count);
  if Length(FFrameState) = 0 then Exit;

  for i := 0 to FPlayState.Count - 1 do
  begin
    ps := FPlayState[i];
    anim := FArmature.GetAnimation(ps.AnimIndex);
    animRange := anim.FramesRange;

    FFrameState[i].animIdx := ps.AnimIndex;
    if ps.KeepAtLastFrame and (ps.Stop <= FTime) then
      FFrameState[i].frameIdx := animRange.y - 1
    else
    begin
      FFrameState[i].frameIdx := frac( TimeToFrameFloat(max(FTime - ps.Start, 0)) / (animRange.y-1)) * (animRange.y-1);
    end;

    if ps.FadeSpeed = 0 then
      fadeWeight := 1
    else
      fadeWeight := clamp(2 - (FTime - ps.Stop)/ps.FadeSpeed, 0, 1);

    if ps.Start >= FTime then
      growWeight := 0
    else
      if ps.GrowSpeed = 0 then
        growWeight := 1
      else
        growWeight := clamp((FTime - ps.Start)/ps.GrowSpeed, 0, 1);
    FFrameState[i].weight := min(fadeWeight, growWeight);
  end;

  summWeight := 0;
  for i := 0 to Length(FFrameState) - 1 do
    summWeight := summWeight + FFrameState[i].weight;
  summWeight := 1.0 / summWeight;
  for i := 0 to Length(FFrameState) - 1 do
    FFrameState[i].weight := FFrameState[i].weight * summWeight;
end;

function TbAnimationController.Contains(const AModelInstance: IbModelInstance): Boolean;
begin
  Result := FModels.IndexOf(AModelInstance) >= 0;
end;

procedure TbAnimationController.AddModel(const AModelInstance: IbModelInstance);
begin
  Assert(AModelInstance <> nil);
  Assert(AModelInstance.MeshInstnace.Armature = FArmature);
  Assert(FModels.IndexOf(AModelInstance) < 0);
  FModels.Add(AModelInstance);
end;

procedure TbAnimationController.DelModel(const AModelInstance: IbModelInstance);
begin
  Assert(AModelInstance <> nil);
  Assert(FModels.IndexOf(AModelInstance) >= 0);
  FModels.DeleteWithSwap(FModels.IndexOf(AModelInstance));
end;

procedure TbAnimationController.StopBoneAnimation(AIndex: Integer; FadeSpeed: Integer);
var panim: PAnimationPlayState;
begin
  panim := FPlayState.PItem[AIndex];
  panim^.FadeSpeed := FadeSpeed;
  panim^.Stop := Min(panim^.Stop, FTime + FadeSpeed);
  panim^.KeepAtLastFrame := False;
end;

procedure TbAnimationController.BoneAnimationSequence(
  const AAnimations: array of string; ALoopedLast: Boolean; GrowSpeed: Integer;
  FadeSpeed: Integer);
var animIdx, i: Integer;
    newAnimation: TAnimationPlayState;
    nextAnimationTime: Int64;
begin
  FAnimIdx.Clear();
  for i := 0 to Length(AAnimations) - 1 do
  begin
    animIdx := FArmature.FindAnimationIndex(AAnimations[i]);
    Assert(animIdx >= 0);
    FAnimIdx.Add(animIdx);
  end;

  for i := 0 to FPlayState.Count - 1 do
    StopBoneAnimation(i, FadeSpeed);

  nextAnimationTime := FTime;
  for i := 0 to FAnimIdx.Count - 1 do
  begin
    animIdx := FAnimIdx[i];
    newAnimation.AnimIndex := animIdx;
    newAnimation.GrowSpeed := GrowSpeed;
    newAnimation.FadeSpeed := FadeSpeed;
    newAnimation.Start := nextAnimationTime;
    newAnimation.KeepAtLastFrame := False;
    newAnimation.Stop := newAnimation.Start + Floor(FArmature.GetAnimation(animIdx).FramesRange.y * KeyFrameDuration);
    nextAnimationTime := newAnimation.Stop - FadeSpeed;

    if i = FAnimIdx.Count - 1 then
    begin
      if ALoopedLast then
        newAnimation.Stop := $7FFFFFFFFFFFFFFF
      else
      begin
        newAnimation.KeepAtLastFrame := True;
        newAnimation.FadeSpeed := 0;
      end;
    end;
    FPlayState.Add(newAnimation);
  end;
end;

constructor TbAnimationController.Create(const AModels: IbModelInstanceArr);
  function CheckSameArmature(): Boolean;
  var i: Integer;
  begin
    for i := 1 to FModels.Count - 1 do
      if FArmature <> FModels[i].MeshInstnace.Armature then
        Exit(False);
    Result := True;
  end;
begin
  Assert(AModels <> nil);
  Assert(AModels.Count > 0);
  Assert(AModels[0].MeshInstnace.Armature <> nil);

  FPlayState := TAnimationPlayStateArr.Create();
  FModels := AModels.Clone();
  FArmature := FModels[0].MeshInstnace.Armature;
  SetLength(FArmatureTransform, FArmature.BonesCount);

  FAnimIdx := TAnimIndices.Create();

  Assert(CheckSameArmature());
end;

{ TbModelColleciton.TModelInstanceVertex }

class function TbModelColleciton.TModelInstanceVertex.Layout: IDataLayout;
begin
  Result := LB.Add('BoneOffset_MaterialOffset', ctInt, 2)
              .Finish();
end;

{ TbModelColleciton.TbModelInstance }

procedure TbModelColleciton.TbModelInstance.GetModelHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle);
begin
  FModel.GetHandles(vert, ind);
end;

procedure TbModelColleciton.TbModelInstance.GetBonesOffset(out ABonesOffset: Integer);
begin
  ABonesOffset := FBns.Offset;
end;

procedure TbModelColleciton.TbModelInstance.GetMaterialsOffset(out AMaterialsOffset: Integer);
begin
  FModel.GetMaterialsOffset(AMaterialsOffset);
end;

function TbModelColleciton.TbModelInstance.Bones: IBones;
begin
  Result := FBonesData;
end;

function TbModelColleciton.TbModelInstance.TexSize: TVec2i;
begin
  Result := FTexSize;
end;

function TbModelColleciton.TbModelInstance.MeshInstnace: IbMeshInstance;
begin
  Result := FMeshInstance;
end;

procedure TbModelColleciton.TbModelInstance.InvalidateBonesData;
begin
  FOwner.FBones.InvalidateNode(FBns);
end;

procedure TbModelColleciton.TbModelInstance.Detach;
begin
  if FOwner = nil then Exit;
  FBns := nil;
  FModel := nil;
  if FOwner.FModelInstances.Last <> Self then
  begin
    FOwner.FModelInstances.Last.FIdx := FIdx;
    FOwner.FModelInstances.DeleteWithSwap(FIdx);
  end;
  FOwner := nil;
end;

constructor TbModelColleciton.TbModelInstance.Create(AOwner: TbModelColleciton; const AMeshInstance: IbMeshInstance);
begin
  FOwner := AOwner;
  FMeshInstance := AMeshInstance;
  FIdx := FOwner.FModelInstances.Add(Self);
  FModel := FOwner.ObtainModel(AMeshInstance.Mesh);
  FBonesData := TBones.Create(AMeshInstance.TransformMatricesCount);
  if FMeshInstance.Armature = nil then
    FMeshInstance.FillNonArmaturedTransform(FBonesData.Matrices);
  FBns := AOwner.FBones.Add(FBonesData);
  FTexSize := AMeshInstance.Mesh.TexturesSize;
end;

destructor TbModelColleciton.TbModelInstance.Destroy;
begin
  Detach();
  inherited Destroy;
end;

{ TbModelColleciton.TBones }

function TbModelColleciton.TBones.VerticesCount: Integer;
begin
  Result := Length(FMatrices);
end;

function TbModelColleciton.TBones.Layout: IDataLayout;
begin
  Result := LB.Add('R0', ctFloat, 4)
              .Add('R1', ctFloat, 4)
              .Add('R2', ctFloat, 4)
              .Add('R3', ctFloat, 4)
              .Finish();
end;

function TbModelColleciton.TBones.Data: TPointerData;
begin
  Result.data := @FMatrices[0];
  Result.size := Length(FMatrices) * SizeOf(FMatrices[0]);
end;

function TbModelColleciton.TBones.Matrices: TMat4Arr;
begin
  Result := FMatrices;
end;

constructor TbModelColleciton.TBones.Create(ASize: Integer);
var
  i: Integer;
begin
  SetLength(FMatrices, ASize);
  for i := 0 to Length(FMatrices) - 1 do
    FMatrices[i] := IdentityMat4;
end;

{ TbModelColleciton }

function TbModelColleciton.ObtainModel(const AMesh: IbMesh): TbModel;
begin
  if not FMeshToModelMap.TryGetValue(AMesh, Result) then
  begin
    Result := TbModel.Create(Self, AMesh);
    FMeshToModelMap.AddOrSet(AMesh, Result);
  end;
end;

function TbModelColleciton.ObtainMultiTexture(const ASize: TVec2i): TavMultiTexture;
begin
  if (ASize.x <= 0) or (ASize.y <= 0) then Exit(nil);
  if not FMaps.TryGetValue(ASize, Result) then
  begin
    Result := TavMultiTexture.Create(Self);
    Result.TargetFormat := TTextureFormat.RGBA;
    FMaps.AddOrSet(ASize, Result);
  end;
end;

function TbModelColleciton.CreateModel(const AMeshInstance: IbMeshInstance): IbModelInstance;
begin
  Result := TbModelInstance.Create(Self, AMeshInstance);
end;

function TbModelColleciton.CreateModels(const AMeshInstanceArr: IbMeshInstanceArr): IbModelInstanceArr;
var
  i: Integer;
begin
  Result := TbModelInstanceArr.Create();
  if AMeshInstanceArr = nil then Exit;
  Result.Capacity := AMeshInstanceArr.Count;
  for i := 0 to AMeshInstanceArr.Count - 1 do
    Result.Add(CreateModel(AMeshInstanceArr[i]));
end;

procedure TbModelColleciton.SubmitBufferClear();
begin
  FToDraw.Clear();
end;

procedure TbModelColleciton.SubmitToDraw(const AModel: IbModelInstance);
begin
  FToDraw.Add(AModel);
end;

procedure TbModelColleciton.SubmitToDraw(const AModelArr: IbModelInstanceArr);
begin
  FToDraw.AddArray(AModelArr);
end;

procedure TbModelColleciton.Draw();

  procedure PrepareDrawChunks;
  var model: IbModelInstance;
      mesh, lastMesh : IbMesh;
      i: Integer;
      drawChunk: TDrawChunk;
  begin
    FDrawChunks.Clear();
    drawChunk.InstanceCount := 0;
    lastMesh := nil;
    for i := 0 to FToDraw.Count - 1 do
    begin
      model := FToDraw[i];
      mesh := model.MeshInstnace.Mesh;
      if drawChunk.InstanceCount <> 0 then
      begin
        if (drawChunk.TexSize <> model.TexSize) or
           (lastMesh <> mesh) then
        begin
          FDrawChunks.Add(drawChunk);
          drawChunk.InstanceCount := 0;
        end;
      end;
      lastMesh := mesh;

      if drawChunk.InstanceCount = 0 then
      begin
        drawChunk.TexSize := model.TexSize;
        drawChunk.InstanceOffset := i;
      end;
      Inc(drawChunk.InstanceCount);
    end;
    if drawChunk.InstanceCount <> 0 then
      FDrawChunks.Add(drawChunk);
  end;

var vh: IVBManagedHandle;
    ih: IIBManagedHandle;
    inst_vertex: TModelInstanceVertex;
    drawchunk: TDrawChunk;
    i, j: Integer;
    lastTexSize: TVec2i;
begin
  if FToDraw.Count = 0 then Exit;
  //prepare batches
  FToDraw.Sort(FDrawComparer);
  PrepareDrawChunks();

  //prepare instance buffer
  FInstBufferData.Clear();
  FInstBuffer.Invalidate;
  for i := 0 to FDrawChunks.Count - 1 do
  begin
    drawchunk := FDrawChunks[i];
    FToDraw[drawchunk.InstanceOffset].GetMaterialsOffset(inst_vertex.MaterialOffset);
    for j := 0 to drawchunk.InstanceCount - 1 do
    begin
      FToDraw[drawchunk.InstanceOffset + j].GetBonesOffset(inst_vertex.BoneOffset);
      FInstBufferData.Add(inst_vertex);
    end;
  end;

  //draw
  Main.ActiveProgram.SetAttributes(FVerts, FInds, FInstBuffer);
  Main.ActiveProgram.SetUniform('Bones', FBones);
  Main.ActiveProgram.SetUniform('Materials', FMaterials);
  lastTexSize := Vec(0, 0);
  for i := 0 to FDrawChunks.Count - 1 do
  begin
    drawchunk := FDrawChunks[i];
    if drawchunk.TexSize <> lastTexSize then
    begin
      Main.ActiveProgram.SetUniform('Maps', ObtainMultiTexture(drawchunk.TexSize), Sampler_Linear);
      lastTexSize := drawchunk.TexSize;
    end;
    FToDraw[drawchunk.InstanceOffset].GetModelHandles(vh, ih);
    Main.ActiveProgram.Draw(ptTriangles, cmNone, True, drawchunk.InstanceCount, ih.Offset, ih.Size, vh.Offset, drawchunk.InstanceOffset);
  end;
end;

constructor TbModelColleciton.Create(AOwner: TavObject);
begin
  inherited Create(AOwner);
  FModelInstances := TbModelInstanceObjArr.Create();
  FMeshToModelMap := TbMeshToModelObjMap.Create();

  FVerts     := TavVBManaged.Create(Self);
  FInds      := TavIBManaged.Create(Self);
  FBones     := TavSBManaged.Create(Self);
  FMaterials := TavSBManaged.Create(Self);
  FMaps      := TMultiTextureMap.Create();

  FInstBufferData := TModelInstanceVertexArr.Create();
  FInstBuffer := TavVB.Create(Self);
  FInstBuffer.Vertices := FInstBufferData as IVerticesData;

  FInds.PrimType := ptTriangles;

  FToDraw := TbModelInstanceArr.Create;
  FDrawComparer := TDrawComparer.Create;
  FDrawChunks := TDrawChunkArr.Create;
end;

destructor TbModelColleciton.Destroy;
var i: Integer;
    models: IbModelObjArr;
    m: TbModel;
begin
  for i := FModelInstances.Count - 1 downto 0 do
    FModelInstances[i].Detach;

  models := TbModelObjArr.Create();
  models.Capacity := FMeshToModelMap.Count;
  FMeshToModelMap.Reset;
  while FMeshToModelMap.NextValue(m) do
    models.Add(m);
  for i := 0 to models.Count - 1 do
    models[i].Detach;

  inherited Destroy;
end;

end.

