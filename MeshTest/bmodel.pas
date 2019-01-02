unit bModel;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, bMesh,
  avTypes, avBase, avTess, avRes, avContnrs,
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
    procedure GetHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle; out bones: IVBManagedHandle);
    function Bones: IBones;
    function MeshInstnace: IbMeshInstance;

    procedure InvalidateBonesData;
  end;
  IbModelArr = {$IfDef FPC}specialize{$EndIf} IArray<IbModelInstance>;
  TbModelArr = {$IfDef FPC}specialize{$EndIf} TArray<IbModelInstance>;
  IbModelSet = {$IfDef FPC}specialize{$EndIf} IHashSet<IbModelInstance>;
  TbModelSet = {$IfDef FPC}specialize{$EndIf} THashSet<IbModelInstance>;

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
    end;

    TbModel = class(TInterfacedObject, IbModel)
    private
      FOwner: TbModelColleciton;
      FMesh : IbMesh;
      FVert : IVBManagedHandle;
      FInd  : IIBManagedHandle;
      procedure GetHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle);
    public
      procedure Detach;
      constructor Create(AOwner: TbModelColleciton; const AMesh: IbMesh);
      destructor Destroy; override;
    end;
    IbModelArr = {$IfDef FPC}specialize{$EndIf} IArray<TbModel>;
    TbModelArr = {$IfDef FPC}specialize{$EndIf} TArray<TbModel>;
    IbMeshToModelObjMap = {$IfDef FPC}specialize{$EndIf} IHashMap<IbMesh, TbModel>;
    TbMeshToModelObjMap = {$IfDef FPC}specialize{$EndIf} THashMap<IbMesh, TbModel>;

    TbModelInstance = class(TInterfacedObject, IbModelInstance)
    private
      FOwner: TbModelColleciton;
      FIdx  : Integer;

      FMeshInstance: IbMeshInstance;
      FModel: TbModel;

      FBns  : ISBManagedHandle;
      FBonesData: IBones;
      procedure GetHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle; out bones: ISBManagedHandle);
      function Bones: IBones;
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
      class function Layout: IDataLayout; static;
    end;
    IModelInstanceVertexArr = {$IfDef FPC}specialize{$EndIf} IArray<TModelInstanceVertex>;
    TModelInstanceVertexArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TModelInstanceVertex>;

  private
    FMeshToModelMap: IbMeshToModelObjMap;
    FModelInstances: IbModelInstanceObjArr;

    FVerts: TavVBManaged;
    FInds : TavIBManaged;
    FBones: TavSBManaged;

    FInstBufferData: IModelInstanceVertexArr;
    FInstBuffer: TavSB;

    function ObtainModel(const AMesh: IbMesh): TbModel;
  public
    function CreateModel(const AMeshInstance: IbMeshInstance): IbModelInstance;

    procedure Select;
    procedure Draw(const AModel: IbModelInstance);

    constructor Create(AOwner: TavObject); override;
    destructor Destroy; override;
  end;

function Create_bAnimationController(const AModel: IbModelInstance): IbAnimationController; overload;
function Create_bAnimationController(const AModels: IbModelArr): IbAnimationController; overload;

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

    FModels: IbModelArr;

    FPlayState : IAnimationPlayStateArr;
    FFrameState: array of TAnimationFrame;

    FAnimIdx: IAnimIndices;

    function TimeToFrameFloat(const AAnim: IbArmatureAnimation; const ATimeFromStart: Int64): Single;
    function TimeToFrame(const AAnim: IbArmatureAnimation; const ATimeFromStart: Int64): Integer;
    procedure SetTime(const ATime: Int64; const AIncomingEvents: IAnimationEventArr = nil);
    procedure UpdateFrameState;

    function  Contains(const AModelInstance: IbModelInstance): Boolean;
    procedure AddModel(const AModelInstance: IbModelInstance);
    procedure DelModel(const AModelInstance: IbModelInstance);

    procedure StopBoneAnimation(AIndex: Integer; FadeSpeed: Integer = Default_FadeSpeed);
    procedure BoneAnimationSequence(const AAnimations: array of string; ALoopedLast: Boolean; GrowSpeed: Integer = Default_FadeSpeed; FadeSpeed: Integer = Default_FadeSpeed);
  public
    constructor Create(const AModels: IbModelArr);
  end;

function Create_bAnimationController(const AModel: IbModelInstance): IbAnimationController;
var models: IbModelArr;
begin
  models := TbModelArr.Create();
  models.Add(AModel);
  Result := Create_bAnimationController(models);
end;

function Create_bAnimationController(const AModels: IbModelArr): IbAnimationController;
begin
  Result := TbAnimationController.Create(AModels);
end;

{ TbModelColleciton.TbModel }

procedure TbModelColleciton.TbModel.GetHandles(out vert: IVBManagedHandle; out
  ind: IIBManagedHandle);
begin
  vert := FVert;
  ind := FInd;
end;

procedure TbModelColleciton.TbModel.Detach;
begin
  if FOwner = nil then Exit;
  FVert := nil;
  FInd := nil;
  FOwner.FMeshToModelMap.Delete(FMesh);
  FOwner := nil;
end;

constructor TbModelColleciton.TbModel.Create(AOwner: TbModelColleciton; const AMesh: IbMesh);
begin
  FOwner := AOwner;
  FMesh := AMesh;
  FOwner.FMeshToModelMap.Add(FMesh, Self);
  FVert := AOwner.FVerts.Add(FMesh.Vert as IVerticesData);
  FInd := AOwner.FInds.Add(FMesh.Ind);
end;

destructor TbModelColleciton.TbModel.Destroy;
begin
  Detach;
  inherited Destroy;
end;

{ TbAnimationController }

function TbAnimationController.TimeToFrameFloat(const AAnim: IbArmatureAnimation; const ATimeFromStart: Int64): Single;
begin
  Result := ATimeFromStart / KeyFrameDuration;
end;

function TbAnimationController.TimeToFrame(const AAnim: IbArmatureAnimation; const ATimeFromStart: Int64): Integer;
begin
  Result := Floor(TimeToFrameFloat(AAnim, ATimeFromStart));
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
            anim.ProcessMarkers(TimeToFrame(anim, max(AOldTime - ps.Start, 0)), TimeToFrame(anim, ANewTime - ps.Start), AIncomingEvents);
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
            anim.ProcessMarkers(TimeToFrame(anim, max(AOldTime - ps.Start, 0)), TimeToFrame(anim, ANewTime - ps.Start), AIncomingEvents);
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
      FFrameState[i].frameIdx := frac( TimeToFrameFloat(anim, max(FTime - ps.Start, 0)) / animRange.y) * animRange.y;
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

constructor TbAnimationController.Create(const AModels: IbModelArr);
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
  FModels := AModels;
  FArmature := FModels[0].MeshInstnace.Armature;
  SetLength(FArmatureTransform, FArmature.BonesCount);

  FAnimIdx := TAnimIndices.Create();

  Assert(CheckSameArmature());
end;

{ TbModelColleciton.TModelInstanceVertex }

class function TbModelColleciton.TModelInstanceVertex.Layout: IDataLayout;
begin
  Result := LB.Add('BoneOffset', ctInt, 1).Finish();
end;

{ TbModelColleciton.TbModelInstance }

procedure TbModelColleciton.TbModelInstance.GetHandles(out vert: IVBManagedHandle; out ind: IIBManagedHandle; out bones: ISBManagedHandle);
begin
  FModel.GetHandles(vert, ind);
  bones := FBns;
end;

function TbModelColleciton.TbModelInstance.Bones: IBones;
begin
  Result := FBonesData;
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
  FBonesData := TBones.Create(AMeshInstance.TransformCount);
  FBns := AOwner.FBones.Add(FBonesData);
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

function TbModelColleciton.CreateModel(const AMeshInstance: IbMeshInstance): IbModelInstance;
begin
  Result := TbModelInstance.Create(Self, AMeshInstance);
end;

procedure TbModelColleciton.Select;
begin
  Main.ActiveProgram.SetAttributes(FVerts, FInds, nil);
end;

procedure TbModelColleciton.Draw(const AModel: IbModelInstance);
var vh: IVBManagedHandle;
    ih: IIBManagedHandle;
    bh: IVBManagedHandle;

    inst_vertex: TModelInstanceVertex;
begin
  AModel.GetHandles(vh, ih, bh);

  inst_vertex.BoneOffset := bh.Offset;

  FInstBufferData.Clear();
  FInstBufferData.Add(inst_vertex);
  FInstBuffer.Invalidate;

  Main.ActiveProgram.SetUniform('Bones', FBones);
  Main.ActiveProgram.SetUniform('Instances', FInstBuffer);

  Main.ActiveProgram.Draw(ptTriangles, cmNone, True, 1, ih.Offset, ih.Size, vh.Offset, 0);
  //DrawManaged(Main.ActiveProgram, vh, ih, nil);
end;

constructor TbModelColleciton.Create(AOwner: TavObject);
begin
  inherited Create(AOwner);
  FModelInstances := TbModelInstanceObjArr.Create();
  FMeshToModelMap := TbMeshToModelObjMap.Create();

  FVerts := TavVBManaged.Create(Self);
  FInds  := TavIBManaged.Create(Self);
  FBones := TavSBManaged.Create(Self);

  FInstBufferData := TModelInstanceVertexArr.Create();
  FInstBuffer := TavSB.Create(Self);
  FInstBuffer.Vertices := FInstBufferData as IVerticesData;

  FInds.PrimType := ptTriangles;
end;

destructor TbModelColleciton.Destroy;
var i: Integer;
    models: IbModelArr;
    m: TbModel;
begin
  for i := FModelInstances.Count - 1 downto 0 do
    FModelInstances[i].Detach;

  models := TbModelArr.Create();
  models.Capacity := FMeshToModelMap.Count;
  FMeshToModelMap.Reset;
  while FMeshToModelMap.NextValue(m) do
    models.Add(m);
  for i := 0 to models.Count - 1 do
    models[i].Detach;

  inherited Destroy;
end;

end.

