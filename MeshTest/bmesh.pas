unit bMesh;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, mutils, avTess, avTypes, avContnrs, avTexLoader;

type
  TbMeshMaterialTextureKind = (tkDiffuse_Intensity,
                               tkDiffuse_Color,
                               tkDiffuse_Alpha,
                               tkDiffuse_Translucency,
                               tkShading_Ambient,
                               tkShading_Emit,
                               tkShading_Mirror,
                               tkShading_RayMirror,
                               tkSpecular_Intensity,
                               tkSpecular_Color,
                               tkSpecular_Hardness,
                               tkGeometry_Normal,
                               tkGeometry_Warp,
                               tkGeometry_Displace);

  TbMeshMaterialTextureInfo = record
    filename: string;
    factor  : Single;
  end;

  { TbMeshMaterialInfo }

  TbMeshMaterialInfo = record
    matDiff        : TVec4;
    matSpec        : TVec4;
    matSpecHardness: Single;
    matSpecIOR     : Single;
    matEmitFactor  : Single;
    Textures: array [TbMeshMaterialTextureKind] of TbMeshMaterialTextureInfo;
    procedure ReadFromStream(const AStream : TStream);
  end;
  PbMeshMaterialInfo = ^TbMeshMaterialInfo;
  TbMeshMaterialInfoArray = array of TbMeshMaterialInfo;

  IbMeshMaterial = interface
    function matInfo : PbMeshMaterialInfo;
    function TexSize : TVec2i;
    function MipCount: Integer;
    function TexData(const ATexKind: TbMeshMaterialTextureKind): ITextureData;
  end;

  TMeshVert = packed record
    vsCoord : TVec3;
    vsNormal: TVec3;
    vsTex   : TVec4;
    vsWeight: TVec4;
    vsWIndex: TVec4i;
    vsMatIdx: Integer;
    class function Layout: IDataLayout; static;
  end;
  PMeshVert = ^TMeshVert;
  IMeshVertArr = {$IfDef FPC}specialize{$EndIf} IArray<TMeshVert>;
  TMeshVertArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TMeshVert>;

  TMeshMorphVert = packed record
    vsCoord : TVec3;
    vsNormal: TVec3;
    class function Layout: IDataLayout; static;
  end;
  PMeshMorphVert = ^TMeshMorphVert;
  IMeshMorphVertArr = {$IfDef FPC}specialize{$EndIf} IArray<TMeshMorphVert>;
  TMeshMorphVertArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TMeshMorphVert>;

  TBlendShapeVertex = packed record
    vsDeltaCoord : TVec3;
    vsDeltaNormal: TVec3;
    vsAtIndex    : Integer;
    class function Layout: IDataLayout; static;
  end;
  PBlendShapeVertex = ^TBlendShapeVertex;
  IBlendShapeVertexArr = {$IfDef FPC}specialize{$EndIf} IArray<TBlendShapeVertex>;
  TBlendShapeVertexArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TBlendShapeVertex>;

  TMorphFrame = record
    Name: string;
    FrameNum: Integer;
    Verts: IMeshMorphVertArr;
  end;
  PMorphFrame = ^TMorphFrame;
  IMorphFrameArr = {$IfDef FPC}specialize{$EndIf} IArray<TMorphFrame>;
  TMorphFrameArr = {$IfDef FPC}specialize{$EndIf} TArray<TMorphFrame>;

  TBlendShape = record
    Name: string;
    Verts: IBlendShapeVertexArr;
  end;
  PBlendShape = ^TBlendShape;
  IBlendShapeArr = {$IfDef FPC}specialize{$EndIf} IArray<TBlendShape>;
  TBlendShapeArr = {$IfDef FPC}specialize{$EndIf} TArray<TBlendShape>;

  IVertexGroupArr = {$IfDef FPC}specialize{$EndIf} IArray<string>;
  TVertexGroupArr = {$IfDef FPC}specialize{$EndIf} TArray<string>;
  IVertexGroupMap = {$IfDef FPC}specialize{$EndIf} IHashMap<string, Integer>;
  TVertexGroupMap = {$IfDef FPC}specialize{$EndIf} THashMap<string, Integer>;

  IbMesh = interface
    function GetName : string;
    function GetVert : IMeshVertArr;
    function GetInd  : IIndices;

    function GetMorphFrames : IMorphFrameArr;
    function GetBlendShapes : IBlendShapeArr;
    function GetVertexGroups: IVertexGroupArr;
    function FindVertexGroup(const AName: string): Integer;

    function GetMaterialsCount(): Integer;
    function GetMaterial(AIndex: Integer): IbMeshMaterial;
    function TexturesSize: TVec2i;

    procedure ApplyMorphFrame(AIndex: Integer);
    procedure ApplyMorphFrameLerp(AFrame: Single);

    property Name: string read GetName;
    property Vert: IMeshVertArr read GetVert;
    property Ind : IIndices read GetInd;
  end;
  IbMeshArr = {$IfDef FPC}specialize{$EndIf} IArray<IbMesh>;
  TbMeshArr = {$IfDef FPC}specialize{$EndIf} TArray<IbMesh>;

  TMarker = record
    name : string;
    frame: Integer;
  end;
  TMarkerArr = array of TMarker;

  TAnimationFrame = record
    animIdx : Integer;
    frameIdx: Single;
    weight  : Single;
  end;

  TAnimationEvent = record
    Animation: string;
    Marker   : string;
  end;
  IAnimationEventArr = {$IfDef FPC}specialize{$EndIf} IArray<TAnimationEvent>;
  TAnimationEventArr = {$IfDef FPC}specialize{$EndIf} TArray<TAnimationEvent>;

  IbArmatureAnimation = interface
    function Name: string;
    function FramesRange: TVec2i;
    function AffectedBones: TIntArr;
    function BoneTransforms(const AFrame: Integer): TMat4Arr;
    function BoneTransform(AIdx: Integer; AFrame: Integer): TMat4;
    function BoneTransformLerp(AIdx: Integer; AFrame: Single): TMat4;

    procedure ProcessMarkers(AFrameStart, AFrameEnd: Integer; const AOutput: IAnimationEventArr);
  end;

  IbArmature = interface
    function GetName : string;

    function BonesCount: Integer;
    function BoneName(AIndex: Integer): string;
    function BoneParent(AIndex: Integer): Integer;
    function BoneTransforms(): TMat4Arr;
    function FindBone(const AName: string): Integer;

    procedure EvalTransform(const AnimFrames: array of TAnimationFrame; var AMat: TMat4Arr);

    function AnimationCount: Integer;
    function GetAnimation(AIndex: Integer): IbArmatureAnimation;
    function FindAnimationIndex(const AName: string): Integer;

    property Name: string read GetName;
  end;
  IbArmatureArr = {$IfDef FPC}specialize{$EndIf} IArray<IbArmature>;
  TbArmatureArr = {$IfDef FPC}specialize{$EndIf} TArray<IbArmature>;

  { IbMeshInstance }

  IbMeshInstance = interface
    function GetArmature: IbArmature;
    function GetName : string;
    function GetTransform: TMat4;
    procedure SetTransform(const AValue: TMat4);

    function Mesh: IbMesh;

    function TransformCount: Integer;
    procedure EvalTransform(const AnimFrames: array of TAnimationFrame; var AMat: TMat4Arr);
    procedure RemapArmatureMatrices(const AArmatureMatrices: TMat4Arr; var AMat: TMat4Arr);

    property Name: string read GetName;
    property Transform: TMat4 read GetTransform write SetTransform;
    property Armature: IbArmature read GetArmature;
  end;
  IbMeshInstanceArr = {$IfDef FPC}specialize{$EndIf} IArray<IbMeshInstance>;
  TbMeshInstanceArr = {$IfDef FPC}specialize{$EndIf} TArray<IbMeshInstance>;

  TImportResult = record
    Armatures: IbArmatureArr;
    Meshes: IbMeshArr;
    MeshInstances: IbMeshInstanceArr;
  end;

function bMesh_LoadFromStream(AStream: TStream; const ATexMan: ITextureManager = nil): TImportResult;
function bMesh_LoadFromFile(const AFileName: string; const ATexMan: ITextureManager = nil): TImportResult;

implementation

uses Math;

type
  EMeshError = class (Exception)
  end;

  { TbMesh }

  TbMesh = class(TInterfacedObject, IbMesh)
  private type

    TbMaterial = class(TInterfacedObject, IbMeshMaterial)
    private
      FMat     : TbMeshMaterialInfo;
      FImages  : array [TbMeshMaterialTextureKind] of ITextureData;
      FTexSize : TVec2i;
      FMipCount: Integer;
      function matInfo : PbMeshMaterialInfo;
      function TexSize : TVec2i;
      function MipCount: Integer;
      function TexData(const ATexKind: TbMeshMaterialTextureKind): ITextureData;
    public
      constructor Create(const AMaterialInfo: TbMeshMaterialInfo; const ATexMan: ITextureManager; ATexWidth, ATexHeight: Integer);
    end;

  private
    FName : string;
    FVerts: IMeshVertArr;
    FInds : IIndices;
    FMorphFrames : IMorphFrameArr;
    FBlendShapes : IBlendShapeArr;
    FVertGroupArr: IVertexGroupArr;
    FVertGroupMap: IVertexGroupMap;

    FTexSize: TVec2i;
    FMaterials: array of IbMeshMaterial;
  private
    function GetName : string;
    function GetVert : IMeshVertArr;
    function GetInd  : IIndices;

    function GetMorphFrames : IMorphFrameArr;
    function GetBlendShapes : IBlendShapeArr;
    function GetVertexGroups: IVertexGroupArr;
    function FindVertexGroup(const AName: string): Integer;

    function GetMaterialsCount(): Integer;
    function GetMaterial(AIndex: Integer): IbMeshMaterial;
    function TexturesSize: TVec2i;

    procedure ApplyMorphFrame(AIndex: Integer);
    procedure ApplyMorphFrameLerp(AFrame: Single);
  public
    constructor Create(AStream: TStream; const AMaterials: TbMeshMaterialInfoArray; const ATexMan: ITextureManager);
  end;

  { TbArmature }

  TbArmature = class(TInterfacedObject, IbArmature)
  private type
    IBoneMap = {$IfDef FPC}specialize{$EndIf} IHashMap<string, Integer>;
    TBoneMap = {$IfDef FPC}specialize{$EndIf} THashMap<string, Integer>;

    TbAnimation = class(TInterfacedObject, IbArmatureAnimation)
    private
      FName : string;
      FRange: TVec2i;
      FBonesIdx: TIntArr;
      FTransforms: array of TMat4Arr;
      FMarkers: TMarkerArr;
    private
      function Name: string;
      function FramesRange: TVec2i;
      function AffectedBones: TIntArr;
      function BoneTransforms(const AFrame: Integer): TMat4Arr;
      function BoneTransform(AIdx: Integer; AFrame: Integer): TMat4;
      function BoneTransformLerp(AIdx: Integer; AFrame: Single): TMat4;
      function Markers: TMarkerArr;

      procedure ProcessMarkers(AFrameStart, AFrameEnd: Integer; const AOutput: IAnimationEventArr);
    public
      constructor Create(AStream: TStream);
    end;
  private
    FName: string;
    FBoneNames : array of string;
    FParents   : TIntArr;
    FTransforms: TMat4Arr;

    FAnimations: array of IbArmatureAnimation;

    FBoneMap: IBoneMap;

    FTempFlags: array of Boolean;
  private
    function GetName : string;

    function BonesCount: Integer;
    function BoneName(AIndex: Integer): string;
    function BoneParent(AIndex: Integer): Integer;
    function BoneTransforms(): TMat4Arr;
    function FindBone(const AName: string): Integer;
    function FindAnimationIndex(const AName: string): Integer;

    procedure EvalTransform(const AnimFrames: array of TAnimationFrame; var AMat: TMat4Arr);

    function AnimationCount: Integer;
    function GetAnimation(AIndex: Integer): IbArmatureAnimation;
  public
    constructor Create(AStream: TStream);
  end;

  { TbMeshInstance }

  TbMeshInstance = class(TInterfacedObject, IbMeshInstance)
  private
    FName: string;
    FTransform: TMat4;
    FMesh: IbMesh;
    FArmature: IbArmature;

    FVGroupToBoneIndex: TIntArr;

    FTempBoneTransform: TMat4Arr;
  private
    function GetArmature: IbArmature;
    function GetName : string;
    function GetTransform: TMat4;
    procedure SetArmature(const AValue: IbArmature);
    procedure SetTransform(const AValue: TMat4);

    function Mesh: IbMesh;

    function TransformCount: Integer;
    procedure EvalTransform(const AnimFrames: array of TAnimationFrame; var AMat: TMat4Arr);
    procedure RemapArmatureMatrices(const AArmatureMatrices: TMat4Arr; var AMat: TMat4Arr);
  public
    constructor Create(AStream: TStream; const AMeshes: IbMeshArr; const AArms: IbArmatureArr);
  end;

function bMesh_LoadFromStream(AStream: TStream; const ATexMan: ITextureManager): TImportResult;
var arm_count, mesh_count, inst_count, mat_count: Integer;
    materials: TbMeshMaterialInfoArray;
    i: Integer;
begin
  mat_count := 0;
  arm_count := 0;
  mesh_count := 0;
  inst_count := 0;

  Result.Armatures := TbArmatureArr.Create();
  Result.Meshes := TbMeshArr.Create();
  Result.MeshInstances := TbMeshInstanceArr.Create();

  AStream.ReadBuffer(mat_count, SizeOf(mat_count));
  SetLength(materials, mat_count);
  for i := 0 to mat_count - 1 do
    materials[i].ReadFromStream(AStream);

  AStream.ReadBuffer(arm_count, SizeOf(arm_count));
  for i := 0 to arm_count - 1 do
    Result.Armatures.Add(TbArmature.Create(AStream));

  AStream.ReadBuffer(mesh_count, SizeOf(mesh_count));
  for i := 0 to mesh_count - 1 do
    Result.Meshes.Add(TbMesh.Create(AStream, materials, ATexMan));

  AStream.ReadBuffer(inst_count, SizeOf(inst_count));
  for i := 0 to inst_count - 1 do
    Result.MeshInstances.Add(TbMeshInstance.Create(AStream, Result.Meshes, Result.Armatures));
end;

function bMesh_LoadFromFile(const AFileName: string; const ATexMan: ITextureManager): TImportResult;
var fs: TFileStream;
    oldDir: string;
begin
  oldDir := GetCurrentDir;
  fs := TFileStream.Create(AFileName, fmOpenRead);
  SetCurrentDir(ExtractFileDir(ExpandFileName(AFileName)));
  try
    Result := bMesh_LoadFromStream(fs, ATexMan);
  finally
    FreeAndNil(fs);
    SetCurrentDir(oldDir);
  end;
end;

{ TbMesh.TbMaterial }

function TbMesh.TbMaterial.matInfo: PbMeshMaterialInfo;
begin
  Result := @FMat;
end;

function TbMesh.TbMaterial.TexSize: TVec2i;
begin
  Result := FTexSize;
end;

function TbMesh.TbMaterial.MipCount: Integer;
begin
  Result := FMipCount;
end;

function TbMesh.TbMaterial.TexData(const ATexKind: TbMeshMaterialTextureKind): ITextureData;
begin
  Result := FImages[ATexKind];
end;

constructor TbMesh.TbMaterial.Create(const AMaterialInfo: TbMeshMaterialInfo; const ATexMan: ITextureManager; ATexWidth, ATexHeight: Integer);
var tk: TbMeshMaterialTextureKind;
begin
  FMat := AMaterialInfo;
  FTexSize.x := ATexWidth;
  FTexSize.y := ATexHeight;
  FMipCount := 0;
  for tk := Low(TbMeshMaterialTextureKind) to High(TbMeshMaterialTextureKind) do
    if AMaterialInfo.Textures[tk].filename <> '' then
    begin
      if ATexMan <> nil then
        FImages[tk] := ATexMan.LoadTexture(AMaterialInfo.Textures[tk].filename, FTexSize.x, FTexSize.y, TImageFormat.A8R8G8B8)
      else
        FImages[tk] := LoadTexture(AMaterialInfo.Textures[tk].filename, FTexSize.x, FTexSize.y, TImageFormat.A8R8G8B8);
      FTexSize.x := FImages[tk].Width;
      FTexSize.y := FImages[tk].Height;
      FMipCount := FImages[tk].MipsCount;
    end
    else
    begin
      FImages[tk] := nil;
    end;
end;

{ TbMeshMaterialInfo }

procedure TbMeshMaterialInfo.ReadFromStream(const AStream: TStream);
var
  tk: TbMeshMaterialTextureKind;
begin
  AStream.ReadBuffer(matDiff, SizeOf(matDiff));
  AStream.ReadBuffer(matSpec, SizeOf(matSpec));
  AStream.ReadBuffer(matSpecHardness, SizeOf(matSpecHardness));
  AStream.ReadBuffer(matSpecIOR, SizeOf(matSpecIOR));
  AStream.ReadBuffer(matEmitFactor, SizeOf(matEmitFactor));
  for tk := Low(TbMeshMaterialTextureKind) to High(TbMeshMaterialTextureKind) do
  begin
    StreamReadString(AStream, Textures[tk].filename);
    if Textures[tk].filename <> '' then
      Textures[tk].filename := ExpandFileName(Textures[tk].filename);
    AStream.ReadBuffer(Textures[tk].factor, SizeOf(Textures[tk].factor));
  end;
end;

{ TbMeshInstance }

function TbMeshInstance.GetArmature: IbArmature;
begin
  Result := FArmature;
end;

function TbMeshInstance.GetName: string;
begin
  Result := FName;
end;

function TbMeshInstance.GetTransform: TMat4;
begin
  Result := FTransform;
end;

procedure TbMeshInstance.SetArmature(const AValue: IbArmature);
var i: Integer;
    vGroups: IVertexGroupArr;
begin
  FArmature := AValue;
  if FArmature = nil then Exit;
  vGroups := FMesh.GetVertexGroups;
  if vGroups.Count = 0 then Exit;
  SetLength(FVGroupToBoneIndex, vGroups.Count);
  for i := 0 to Length(FVGroupToBoneIndex) - 1 do
  begin
    FVGroupToBoneIndex[i] := FArmature.FindBone(vGroups[i]);
    if FVGroupToBoneIndex[i] < 0 then
      raise EMeshError.CreateFmt('Can''t bind "%s" vertex group to bone at mesh "%s" with armature "%s"', [vGroups[i], FMesh.Name, FArmature.Name]);
  end;
end;

procedure TbMeshInstance.SetTransform(const AValue: TMat4);
begin
  FTransform := AValue;
end;

function TbMeshInstance.Mesh: IbMesh;
begin
  Result := FMesh;
end;

function TbMeshInstance.TransformCount: Integer;
begin
  Result := Max(1, FMesh.GetVertexGroups.Count);
end;

procedure TbMeshInstance.EvalTransform(const AnimFrames: array of TAnimationFrame; var AMat: TMat4Arr);
var
  i: Integer;
begin
  Assert(Length(AMat) = TransformCount);
  if (Length(AnimFrames) = 0) or (FArmature = nil) then
  begin
    for i := 0 to Length(AMat) - 1 do
      AMat[i] := FTransform;
    Exit;
  end;

  FArmature.EvalTransform(AnimFrames, FTempBoneTransform);

  RemapArmatureMatrices(FTempBoneTransform, AMat);
end;

procedure TbMeshInstance.RemapArmatureMatrices(const AArmatureMatrices: TMat4Arr; var AMat: TMat4Arr);
var
  i: Integer;
begin
  for i := 0 to Length(FVGroupToBoneIndex) - 1 do
    AMat[i] := AArmatureMatrices[FVGroupToBoneIndex[i]] * FTransform;
end;

constructor TbMeshInstance.Create(AStream: TStream; const AMeshes: IbMeshArr; const AArms: IbArmatureArr);
var idx: Integer;
begin
  idx := 0;
  StreamReadString(AStream, FName);
  AStream.ReadBuffer(FTransform, SizeOf(FTransform));
  AStream.ReadBuffer(idx, SizeOf(idx));
  FMesh := AMeshes[idx];
  AStream.ReadBuffer(idx, SizeOf(idx));
  if idx >= 0 then
    SetArmature(AArms[idx]);
end;

{ TbArmature.TbAnimation }

function TbArmature.TbAnimation.Name: string;
begin
  Result := FName;
end;

function TbArmature.TbAnimation.FramesRange: TVec2i;
begin
  Result := FRange;
end;

function TbArmature.TbAnimation.AffectedBones: TIntArr;
begin
  Result := FBonesIdx;
end;

function TbArmature.TbAnimation.BoneTransforms(const AFrame: Integer): TMat4Arr;
begin
  Result := FTransforms[AFrame - FRange.x];
end;

function TbArmature.TbAnimation.BoneTransform(AIdx: Integer; AFrame: Integer): TMat4;
begin
  Result := FTransforms[AFrame][AIdx];
end;

function TbArmature.TbAnimation.BoneTransformLerp(AIdx: Integer; AFrame: Single): TMat4;
var prev, next: Integer;
begin
  AFrame := AFrame - FRange.x;
  prev := Floor(AFrame);
  next := Min(prev + 1, Length(FTransforms));
  Result := Lerp(FTransforms[prev][AIdx], FTransforms[next][AIdx], AFrame - prev);
end;

function TbArmature.TbAnimation.Markers: TMarkerArr;
begin
  Result := FMarkers;
end;

procedure TbArmature.TbAnimation.ProcessMarkers(AFrameStart, AFrameEnd: Integer; const AOutput: IAnimationEventArr);
var animEvent: TAnimationEvent;
    cut, i: Integer;
begin
  if AFrameEnd <= AFrameStart then Exit;
  cut := (AFrameStart div FRange.y) * FRange.y;
  AFrameStart := AFrameStart - cut;
  AFrameEnd := AFrameEnd - cut;
  while AFrameEnd > 0 do
  begin
    for i := 0 to Length(FMarkers) - 1 do
    begin
      if (AFrameStart <= FMarkers[i].frame) and (AFrameEnd > FMarkers[i].frame) then
      begin
        animEvent.Animation := Name;
        animEvent.Marker := FMarkers[i].name;
        AOutput.Add(animEvent);
      end;
    end;
    AFrameStart := 0;
    AFrameEnd := AFrameEnd - FRange.y;
  end;
end;

constructor TbArmature.TbAnimation.Create(AStream: TStream);
var bones_count, markers_count: Integer;
    i: Integer;
begin
  bones_count := 0;
  markers_count := 0;

  StreamReadString(AStream, FName);

  AStream.ReadBuffer(markers_count, SizeOf(markers_count));
  SetLength(FMarkers, markers_count);
  for i := 0 to markers_count - 1 do
  begin
    StreamReadString(AStream, FMarkers[i].name);
    AStream.ReadBuffer(FMarkers[i].frame, SizeOf(Integer));
  end;

  AStream.ReadBuffer(bones_count, SizeOf(bones_count));
  Assert(bones_count > 0);

  SetLength(FBonesIdx, bones_count);
  AStream.ReadBuffer(FBonesIdx[0], SizeOf(Integer) * bones_count);

  AStream.ReadBuffer(FRange, SizeOf(FRange));
  SetLength(FTransforms, FRange.y - FRange.x);
  for i := 0 to Length(FTransforms) - 1 do
  begin
    SetLength(FTransforms[i], bones_count);
    AStream.ReadBuffer(FTransforms[i][0], SizeOf(TMat4) * bones_count);
  end;
end;

{ TbArmature }

function TbArmature.GetName: string;
begin
  Result := FName;
end;

function TbArmature.BonesCount: Integer;
begin
  Result := Length(FTransforms);
end;

function TbArmature.BoneName(AIndex: Integer): string;
begin
  Result := FBoneNames[AIndex];
end;

function TbArmature.BoneParent(AIndex: Integer): Integer;
begin
  Result := FParents[AIndex];
end;

function TbArmature.BoneTransforms(): TMat4Arr;
begin
  Result := FTransforms;
end;

function TbArmature.FindBone(const AName: string): Integer;
var i: Integer;
begin
  if FBoneMap = nil then
  begin
    FBoneMap := TBoneMap.Create();
    for i := 0 to Length(FBoneNames) - 1 do
      FBoneMap.AddOrSet(FBoneNames[i], i);
  end;
  if not FBoneMap.TryGetValue(AName, Result) then
    Result := -1;
end;

function TbArmature.FindAnimationIndex(const AName: string): Integer;
var i: Integer;
begin
  for i := 0 to Length(FAnimations) - 1 do
    if FAnimations[i].Name = AName then Exit(i);
  Result := -1;
end;

procedure TbArmature.EvalTransform(const AnimFrames: array of TAnimationFrame; var AMat: TMat4Arr);

  procedure UpdateAbsTransform(AIndex: Integer);
  var parentIdx: Integer;
  begin
    if not FTempFlags[AIndex] then
    begin
      parentIdx := FParents[AIndex];
      if parentIdx < 0 then
        AMat[AIndex] := AMat[AIndex]
      else
      begin
        UpdateAbsTransform(parentIdx);
        AMat[AIndex] := AMat[AIndex] * AMat[parentIdx];
      end;
      FTempFlags[AIndex] := True;
    end;
  end;

var
  i, j: Integer;
  af: TAnimationFrame;
  anim: IbArmatureAnimation;
  range: TVec2i;
  frames: TVec2i;
  t: TVec2;
  animIndices: TIntArr;
begin
  Assert(Length(AMat) = BonesCount);

  for i := 0 to Length(AMat) - 1 do
  begin
    AMat[i] := ZeroMat4;
    FTempFlags[i] := False;
  end;

  //apply all animations
  for i := 0 to Length(AnimFrames) - 1 do
  begin
    af := AnimFrames[i];
    if af.weight < 0.0001 then Continue;

    anim := FAnimations[i];
    range := anim.FramesRange;
    frames.x := Floor(af.frameIdx);
    frames.y := min(frames.x + 1, range.y - range.x - 1);
    t.y := af.frameIdx - frames.x;
    t.x := 1.0 - t.y;
    t := t * af.weight;
    animIndices := anim.AffectedBones;
    for j := 0 to Length(animIndices) - 1 do
      AMat[animIndices[j]] := AMat[animIndices[j]] + anim.BoneTransform(j, frames.x)*t.x + anim.BoneTransform(j, frames.y)*t.y;
  end;

  //update uninitialized matrices with identity matrix
  for i := 0 to Length(AMat) - 1 do
    if abs(AMat[i].f[3,3]) < 0.0001 then
      AMat[i] := IdentityMat4;

  //eval absolute transforms
  for i := 0 to Length(AMat) - 1 do
    UpdateAbsTransform(i);
end;

function TbArmature.AnimationCount: Integer;
begin
  Result := Length(FAnimations);
end;

function TbArmature.GetAnimation(AIndex: Integer): IbArmatureAnimation;
begin
  Result := FAnimations[AIndex];
end;

constructor TbArmature.Create(AStream: TStream);
var bones_count, anim_count: Integer;
    i: Integer;
begin
  bones_count := 0;
  anim_count := 0;

  StreamReadString(AStream, FName);
  AStream.ReadBuffer(bones_count, SizeOf(bones_count));
  Assert(bones_count > 0);

  SetLength(FBoneNames, bones_count);
  for i := 0 to bones_count - 1 do
    StreamReadString(AStream, FBoneNames[i]);

  SetLength(FParents, bones_count);
  AStream.ReadBuffer(FParents[0], SizeOf(Integer) * bones_count);

  SetLength(FTransforms, bones_count);
  SetLength(FTempFlags, bones_count);
  AStream.ReadBuffer(FTransforms[0], SizeOf(TMat4) * bones_count);

  AStream.ReadBuffer(anim_count, SizeOf(anim_count));
  SetLength(FAnimations, anim_count);
  for i := 0 to anim_count - 1 do
    FAnimations[i] := TbAnimation.Create(AStream);
end;

{ TbMesh }

procedure TbMesh.ApplyMorphFrame(AIndex: Integer);
var i: Integer;
    pVert: PMeshVert;
    pMorphVert: PMeshMorphVert;
begin
  pVert := FVerts.PItem[0];
  pMorphVert := FMorphFrames[AIndex].Verts.PItem[0];
  for i := 0 to FVerts.Count - 1 do
  begin
    pVert^.vsCoord := pMorphVert^.vsCoord;
    pVert^.vsNormal := pMorphVert^.vsNormal;
    Inc(pVert);
    Inc(pMorphVert);
  end;
end;

procedure TbMesh.ApplyMorphFrameLerp(AFrame: Single);
var i: Integer;
    pVert: PMeshVert;
    pMorphVertPrev, pMorphVertNext: PMeshMorphVert;
    prevFrame: Integer;
    nextFrame: Integer;
    t: Single;
begin
  prevFrame := Floor(AFrame);
  nextFrame := Ceil(AFrame);
  t := AFrame - prevFrame;
  prevFrame := prevFrame mod FMorphFrames.Count();
  nextFrame := nextFrame mod FMorphFrames.Count();
  if prevFrame < 0 then prevFrame := prevFrame + FMorphFrames.Count();
  if nextFrame < 0 then nextFrame := nextFrame + FMorphFrames.Count();

  pVert := FVerts.PItem[0];
  pMorphVertPrev := FMorphFrames[prevFrame].Verts.PItem[0];
  pMorphVertNext := FMorphFrames[nextFrame].Verts.PItem[0];
  for i := 0 to FVerts.Count - 1 do
  begin
    pVert^.vsCoord := Lerp(pMorphVertPrev^.vsCoord, pMorphVertNext^.vsCoord, t);
    pVert^.vsNormal := Lerp(pMorphVertPrev^.vsNormal, pMorphVertNext^.vsNormal, t);
    Inc(pVert);
    Inc(pMorphVertPrev);
    Inc(pMorphVertNext);
  end;
end;

function TbMesh.GetName: string;
begin
  Result := FName;
end;

function TbMesh.GetVert: IMeshVertArr;
begin
  Result := FVerts;
end;

function TbMesh.GetInd: IIndices;
begin
  Result := FInds;
end;

function TbMesh.GetMorphFrames: IMorphFrameArr;
begin
  Result := FMorphFrames;
end;

function TbMesh.GetBlendShapes: IBlendShapeArr;
begin
  Result := FBlendShapes;
end;

function TbMesh.GetVertexGroups: IVertexGroupArr;
begin
  Result := FVertGroupArr;
end;

function TbMesh.FindVertexGroup(const AName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  if FVertGroupArr.Count = 0 then Exit;
  if FVertGroupMap = nil then
  begin
    FVertGroupMap := TVertexGroupMap.Create();
    for i := 0 to FVertGroupArr.Count - 1 do
      FVertGroupMap.Add(FVertGroupArr[i], i);
  end;
  if not FVertGroupMap.TryGetValue(AName, Result) then
    Result := -1;
end;

function TbMesh.GetMaterialsCount(): Integer;
begin
  Result := Length(FMaterials);
end;

function TbMesh.GetMaterial(AIndex: Integer): IbMeshMaterial;
begin
  Result := FMaterials[AIndex];
end;

function TbMesh.TexturesSize: TVec2i;
begin
  Result := FTexSize;
end;

constructor TbMesh.Create(AStream: TStream; const AMaterials: TbMeshMaterialInfoArray; const ATexMan: ITextureManager);
var vert_count, morph_count, ind_count, bshape_count, bshape_vert_count, vgroup_count: Integer;
    i, j: Integer;
    pMVert: PMeshVert;
    pMorph: PMorphFrame;
    pShape: PBlendShape;
    weight_count: Integer;
    pWIndex: PInteger;
    pWeight: PSingle;
    astr: AnsiString;
    mat_count: Integer;
    mat_idx: Integer;
begin
  mat_count := 0;
  mat_idx := 0;
  vert_count := 0;
  morph_count := 0;
  ind_count := 0;
  bshape_count := 0;
  bshape_vert_count := 0;
  weight_count := 0;
  vgroup_count := 0;

  StreamReadString(AStream, FName);

  FTexSize.x := SIZE_DEFAULT;
  FTexSize.y := SIZE_DEFAULT;
  AStream.ReadBuffer(mat_count, SizeOf(mat_count));
  SetLength(FMaterials, mat_count);
  for i := 0 to mat_count - 1 do
  begin
    AStream.ReadBuffer(mat_idx, SizeOf(mat_idx));
    FMaterials[i] := TbMaterial.Create(AMaterials[mat_idx], ATexMan, FTexSize.x, FTexSize.y);
    FTexSize := FMaterials[i].TexSize;
  end;
  if (FTexSize.x <= 0) or (FTexSize.y <= 0) then FTexSize := Vec(0,0);

  AStream.ReadBuffer(vert_count, SizeOf(vert_count));
  Assert(vert_count > 0);
  FVerts := TMeshVertArr.Create();
  FVerts.SetSize(vert_count);
  pMVert := FVerts.PItem[0];
  for i := 0 to vert_count - 1 do
  begin
    AStream.ReadBuffer(pMVert^.vsTex, SizeOf(pMVert^.vsTex));

    pMVert^.vsWIndex := Vec(0, -1, -1, -1);
    AStream.ReadBuffer(weight_count, SizeOf(weight_count));
    pWIndex := @pMVert^.vsWIndex;
    pWeight := @pMVert^.vsWeight;
    for j := 0 to weight_count - 1 do
    begin
      AStream.ReadBuffer(pWIndex^, SizeOf(Integer));
      AStream.ReadBuffer(pWeight^, SizeOf(Single));
      Inc(pWIndex);
      Inc(pWeight);
    end;

    AStream.ReadBuffer(pMVert^.vsMatIdx, SizeOf(pMVert^.vsMatIdx));
    Inc(pMVert);
  end;

  AStream.ReadBuffer(morph_count, SizeOf(morph_count));
  Assert(morph_count > 0);
  FMorphFrames := TMorphFrameArr.Create();
  FMorphFrames.SetSize(morph_count);
  pMorph := FMorphFrames.PItem[0];
  for i := 0 to morph_count - 1 do
  begin
    StreamReadString(AStream, pMorph^.Name);
    AStream.ReadBuffer(pMorph^.FrameNum, SizeOf(pMorph^.FrameNum));
    pMorph^.Verts := TMeshMorphVertArr.Create();
    pMorph^.Verts.SetSize(vert_count);
    AStream.ReadBuffer(pMorph^.Verts.PItem[0]^, SizeOf(TMeshMorphVert) * vert_count);
    Inc(pMorph);
  end;

  AStream.ReadBuffer(ind_count, SizeOf(ind_count));
  Assert(ind_count > 0);
  FInds := Create_IIndices;
  FInds.IsDWord := True;
  FInds.Count := ind_count;
  FInds.PrimitiveType := ptTriangles;
  AStream.ReadBuffer(FInds.Data.data^, SizeOf(Integer) * ind_count);

  AStream.ReadBuffer(bshape_count, SizeOf(bshape_count));
  FBlendShapes := TBlendShapeArr.Create();
  FBlendShapes.SetSize(bshape_count);
  if bshape_count > 0 then
  begin
    pShape := FBlendShapes.PItem[0];
    StreamReadString(AStream, pShape^.Name);
    AStream.ReadBuffer(bshape_vert_count, SizeOf(bshape_vert_count));
    pShape^.Verts := TBlendShapeVertexArr.Create();
    pShape^.Verts.SetSize(bshape_vert_count);
    AStream.ReadBuffer(pShape^.Verts.PItem[0]^, bshape_vert_count * SizeOf(TBlendShapeVertex));
  end;

  FVertGroupArr := TVertexGroupArr.Create();
  AStream.ReadBuffer(vgroup_count, SizeOf(vgroup_count));
  FVertGroupArr.Capacity := vgroup_count;
  for i := 0 to vgroup_count - 1 do
  begin
    StreamReadString(AStream, astr);
    FVertGroupArr.Add(astr);
  end;

  ApplyMorphFrame(0);
end;

{ TMeshVertex }

class function TMeshVert.Layout: IDataLayout;
begin
  Result := LB.Add('vsCoord', ctFloat, 3)
              .Add('vsNormal', ctFloat, 3)
              .Add('vsTex', ctFloat, 4)
              .Add('vsWeight', ctFloat, 4)
              .Add('vsWIndex', ctInt, 4)
              .Add('vsMatIdx', ctInt, 1)
              .Finish();
end;

{ TMeshMorphVert }

class function TMeshMorphVert.Layout: IDataLayout;
begin
  Result := LB.Add('vsCoord', ctFloat, 3)
              .Add('vsNormal', ctFloat, 3)
              .Finish();
end;

{ TBlendShapeVertex }

class function TBlendShapeVertex.Layout: IDataLayout;
begin
  Result := LB.Add('vsDeltaCoord', ctFloat, 3)
              .Add('vsDeltaNormal', ctFloat, 3)
              .Add('vsAtIndex', ctInt, 1)
              .Finish();
end;

end.
