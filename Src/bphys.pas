unit bPhys;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, avContnrs, mutils, Newton;

type
  TPhysColliderKind = (ckBox, ckCapsule, ckCompound);

  IPhysCollider = interface
  ['{6D35EC76-E9F4-41D8-9098-4EC61DD7DF9B}']
    function Handle: NewtonCollision;
    function Kind: TPhysColliderKind;
  end;
  TPhysColliderArr = {$IfDef FPC}specialize{$EndIf} TArray<IPhysCollider>;
  IPhysColliderArr = {$IfDef FPC}specialize{$EndIf} IArray<IPhysCollider>;

  IPhysCollider_Box = interface (IPhysCollider)
  ['{D4E8BD0C-6806-4D2E-A747-8ED2DA711557}']
    function Size  : TVec3;
    function Offset: TVec3;
  end;

  IPhysCollider_Capsule = interface (IPhysCollider)
  ['{3382961E-64E1-4B2D-8023-692A174529CA}']
    function Radius : Single;
    function LengthX: Single;
    function Offset : TVec3;
  end;

  IPhysCollider_Compound = interface (IPhysCollider)
  ['{5E2973E0-CB01-4A37-B2B7-FB02D7630DF2}']
    function ChildsCount: Integer;
    function GetChild(const AIndex: Integer): IPhysCollider;
  end;

  IPhysMaterial = interface
  ['{8190FC7D-0B59-47CC-9719-F205368CB69F}']
  end;

  TPhysBodyKind = (bkStatic, bkDynamic, bkKinematic);

  { IPhysBody }

  IPhysBody = interface
  ['{895B1B00-DEC1-4222-9774-038A37C9B829}']
    function Handle: NewtonBody;

    function GetPos: TVec3;
    function GetRot: TQuat;
    function GetTransform: TMat4;
    procedure SetPos(const AValue: TVec3);
    procedure SetRot(const AValue: TQuat);
    procedure SetTransform(const AValue: TMat4);

    function Collider: IPhysCollider;
    function Kind: TPhysBodyKind;

    property Pos: TVec3 read GetPos write SetPos;
    property Rot: TQuat read GetRot write SetRot;
    property Transform: TMat4 read GetTransform write SetTransform;
  end;

  IPhysBody_Static = interface (IPhysBody)
  ['{864D34CD-2215-49ED-B628-41805ED63652}']
  end;

  { IPhysBody_Dynamic }

  IPhysBody_Dynamic = interface (IPhysBody)
  ['{88BB3C93-C049-4393-9C5A-88FC797149EB}']
    function  GetMass: TVec4;
    function  GetMassOrigin: TVec3;
    procedure SetMass(const AValue: TVec4);
    procedure SetMassOrigin(const AValue: TVec3);

    property Mass: TVec4 read GetMass write SetMass; //xyz - moment of inertia, w - mass
    property MassOrigin: TVec3 read GetMassOrigin write SetMassOrigin;
  end;

  IPhysJoint = interface
  ['{C2DFAE9E-2311-4055-BF49-FD79196F6301}']
    function Handle: NewtonJoint;
  end;

  IPhysJoint_UpConstraint = interface (IPhysJoint)
  ['{8A33421D-50C9-4AEB-ACCB-2720008AED53}']
    function GetUpVector: TVec3;
    procedure SetUpVector(const AValue: TVec3);

    function Body: IPhysBody;

    property UpVector: TVec3 read GetUpVector write SetUpVector;
  end;

  { IPhysWorld }

  IPhysWorld = interface
  ['{3F3046BB-8A43-4049-9724-579DA87ED453}']
    function GetGravity: TVec3;
    procedure SetGravity(const AValue: TVec3);

    function Handle: NewtonWorld;

    function CreateCollider_Box(const ABoxSize: TVec3; const AOffset: TVec3): IPhysCollider_Box;
    function CreateCollider_Capsule(ARadius, ALengthX: Single; const AOffset: TVec3): IPhysCollider_Capsule;

    function CreateCollider_Compound(const AChildColliders: IPhysColliderArr): IPhysCollider_Compound; overload;
    function CreateCollider_Compound(const AChildColliders: IPhysColliderArr; const ATransforms: array of TMat4): IPhysCollider_Compound; overload;
    function CreateCollider_Compound(const AChildColliders: array of IPhysCollider; const ATransforms: array of TMat4): IPhysCollider_Compound; overload;

    function CreateBody_Static (const ACollider: IPhysCollider; const ATransform: TMat4): IPhysBody_Static;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single): IPhysBody_Dynamic; overload;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4): IPhysBody_Dynamic; overload;

    function CreateJoint_UpConstraint(const ABody: IPhysBody; const AUpVector: TVec3): IPhysJoint_UpConstraint;

    procedure UpdateStep(AIntervalMSec: Integer);

    property Gravity: TVec3 read GetGravity write SetGravity;
  end;

function Create_IPhysWorld: IPhysWorld;

implementation

type
  TPhysWorld = class;

  { TPhysChild }

  TPhysChild = class (TInterfacedObject)
  strict private
    FWorldRef: IPhysWorld;
    FWorld: TPhysWorld;
  protected
    property World: TPhysWorld read FWorld;
  public
    constructor Create(const AWorld: TPhysWorld); virtual;
  end;

  { TCollider }

  TCollider = class (TPhysChild, IPhysCollider)
  protected
    FHandle: NewtonCollision;
  public
    function Handle: NewtonCollision;
    function Kind: TPhysColliderKind; virtual; abstract;
    destructor Destroy; override;
  end;

  { TCollider_Box }

  TCollider_Box = class (TCollider, IPhysCollider_Box)
  private
    FSize: TVec3;
    FOffset: TVec3;
  public
    function Size  : TVec3;
    function Offset: TVec3;
    function Kind: TPhysColliderKind; override;
    constructor Create(const AWorld: TPhysWorld; const ASize, AOffset: TVec3); overload;
  end;

  { TCollider_Capsule }

  TCollider_Capsule = class (TCollider, IPhysCollider_Capsule)
  private
    FLengthX: Single;
    FOffset : TVec3;
    FRadius : Single;
  public
    function Kind: TPhysColliderKind; override;
    function Radius : Single;
    function LengthX: Single;
    function Offset : TVec3;
    constructor Create(const AWorld: TPhysWorld; ARadius, ALengthX: Single; const AOffset: TVec3); overload;
  end;

  { TCollider_Compound }

  TCollider_Compound = class (TCollider, IPhysCollider_Compound)
  private
    FChilds: IPhysColliderArr;
    function ChildsCount: Integer;
    function GetChild(const AIndex: Integer): IPhysCollider;
  public
    function Kind: TPhysColliderKind; override;
    constructor Create(const AWorld: TPhysWorld; const AColliders: IPhysColliderArr); overload;
    constructor Create(const AWorld: TPhysWorld; const AColliders: IPhysColliderArr; const ATransforms: array of TMat4); overload;
    constructor Create(const AWorld: TPhysWorld; const AColliders: array of IPhysCollider; const ATransforms: array of TMat4); overload;
  end;

  TMaterial = class (TPhysChild, IPhysMaterial)
  private
  public
  end;

  { TBody }

  TBody = class (TPhysChild, IPhysBody)
  protected
    FHandle: NewtonBody;
    FCollider: IPhysCollider;
    function Handle: NewtonBody;
    function Collider: IPhysCollider;
    function Kind: TPhysBodyKind; virtual; abstract;

    function GetPos: TVec3;
    function GetRot: TQuat;
    function GetTransform: TMat4;
    procedure SetPos(const AValue: TVec3);
    procedure SetRot(const AValue: TQuat);
    procedure SetTransform(const AValue: TMat4);
  public
    destructor Destroy; override;
    procedure AfterConstruction; override;
  end;

  { TBody_Static }

  TBody_Static = class (TBody, IPhysBody_Static)
  protected
    function Kind: TPhysBodyKind; override;
  public
    constructor Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4); overload;
  end;

  { TBody_Dynamic }

  TBody_Dynamic = class (TBody, IPhysBody_Dynamic)
  protected
    function Kind: TPhysBodyKind; override;
    function  GetMass: TVec4;
    function  GetMassOrigin: TVec3;
    procedure SetMass(const AValue: TVec4);
    procedure SetMassOrigin(const AValue: TVec3);
  public
    constructor Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single); overload;
    constructor Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4); overload;
  end;

  { TJoint }

  TJoint = class (TPhysChild, IPhysJoint)
  protected
    FHandle: NewtonJoint;
    function Handle: NewtonJoint;
  public
    destructor Destroy; override;
  end;

  { TJoint_UpConstraint }

  TJoint_UpConstraint = class (TJoint, IPhysJoint_UpConstraint)
  private
    FBody: IPhysBody;
    function GetUpVector: TVec3;
    procedure SetUpVector(const AValue: TVec3);

    function Body: IPhysBody;
  public
    constructor Create(const AWorld: TPhysWorld; const ABody: IPhysBody; const AUp: TVec3); overload;
  end;

  { TPhysWorld }

  TPhysWorld = class (TInterfacedObject, IPhysWorld)
  private
    FGravity: TVec3;
    FWorld: NewtonWorld;

    procedure DoApplyForceAndTorque(ABody: TBody; timestep : dFloat; threadIndex : Integer);
  private
    function GetGravity: TVec3;
    procedure SetGravity(const AValue: TVec3);

    function Handle: NewtonWorld;

    function CreateCollider_Box(const ABoxSize: TVec3; const AOffset: TVec3): IPhysCollider_Box;
    function CreateCollider_Capsule(ARadius, ALengthX: Single; const AOffset: TVec3): IPhysCollider_Capsule;
    function CreateCollider_Compound(const AChildColliders: IPhysColliderArr): IPhysCollider_Compound; overload;
    function CreateCollider_Compound(const AChildColliders: IPhysColliderArr; const ATransforms: array of TMat4): IPhysCollider_Compound; overload;
    function CreateCollider_Compound(const AChildColliders: array of IPhysCollider; const ATransforms: array of TMat4): IPhysCollider_Compound; overload;

    function CreateBody_Static(const ACollider: IPhysCollider; const ATransform: TMat4): IPhysBody_Static;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single): IPhysBody_Dynamic; overload;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4): IPhysBody_Dynamic; overload;

    function CreateJoint_UpConstraint(const ABody: IPhysBody; const AUpVector: TVec3): IPhysJoint_UpConstraint;

    procedure UpdateStep(AIntervalMSec: Integer);
  public
    constructor Create();
    destructor Destroy; override;
  end;

procedure Callback_ApplyForceAndTorque(const body : NewtonBody; timestep : dFloat; threadIndex : Integer); cdecl;
var obj: TBody;
begin
  obj := TBody(NewtonBodyGetUserData(body));
  obj.World.DoApplyForceAndTorque(obj, timestep, threadIndex);
end;

function Create_IPhysWorld: IPhysWorld;
begin
  Result := TPhysWorld.Create();
end;

{ TCollider }

function TCollider.Handle: NewtonCollision;
begin
  Result := FHandle;
end;

destructor TCollider.Destroy;
begin
  if FHandle <> nil then
  begin
    NewtonDestroyCollision(FHandle);
    FHandle := nil;
  end;
  inherited Destroy;
end;

{ TCollider_Box }

function TCollider_Box.Size: TVec3;
begin
  Result := FSize;
end;

function TCollider_Box.Offset: TVec3;
begin
  Result := FOffset;
end;

function TCollider_Box.Kind: TPhysColliderKind;
begin
  Result := ckBox;
end;

constructor TCollider_Box.Create(const AWorld: TPhysWorld; const ASize, AOffset: TVec3);
var m: TMat4;
begin
  Create(AWorld);
  m := MatTranslate(AOffset);
  FHandle := NewtonCreateBox(World.Handle, ASize.x, ASize.y, ASize.z, 0, @m);
  FSize := ASize;
  FOffset := AOffset;
end;

{ TCollider_Capsule }

function TCollider_Capsule.Kind: TPhysColliderKind;
begin
  Result := ckCapsule;
end;

function TCollider_Capsule.Radius: Single;
begin
  Result := FRadius;
end;

function TCollider_Capsule.LengthX: Single;
begin
  Result := FLengthX;
end;

function TCollider_Capsule.Offset: TVec3;
begin
  Result := FOffset;
end;

constructor TCollider_Capsule.Create(const AWorld: TPhysWorld; ARadius, ALengthX: Single; const AOffset: TVec3);
var
  m: TMat4;
begin
  Create(AWorld);
  m := MatTranslate(AOffset);
  FHandle := NewtonCreateCapsule(AWorld.Handle, ARadius, ARadius, ALengthX, 0, @m);
  FRadius := ARadius;
  FLengthX := ALengthX;
  FOffset := AOffset;
end;

{ TCollider_Compound }

function TCollider_Compound.ChildsCount: Integer;
begin
  Result := FChilds.Count;
end;

function TCollider_Compound.GetChild(const AIndex: Integer): IPhysCollider;
begin
  Result := FChilds[AIndex];
end;

function TCollider_Compound.Kind: TPhysColliderKind;
begin
  Result := ckCompound;
end;

constructor TCollider_Compound.Create(const AWorld: TPhysWorld; const AColliders: IPhysColliderArr);
var
  i: Integer;
begin
  Create(AWorld);
  FHandle := NewtonCreateCompoundCollision(World.Handle, 0);

  FChilds := TPhysColliderArr.Create;
  FChilds.Capacity := AColliders.Count;

  NewtonCompoundCollisionBeginAddRemove(FHandle);
  for i := 0 to AColliders.Count - 1 do
  begin
    FChilds[i] := AColliders[i];
    NewtonCompoundCollisionAddSubCollision(FHandle, FChilds[i].Handle);
  end;
  NewtonCompoundCollisionEndAddRemove(FHandle);
end;

constructor TCollider_Compound.Create(const AWorld: TPhysWorld; const AColliders: IPhysColliderArr; const ATransforms: array of TMat4);
var node: Pointer;
  i: Integer;
begin
  Create(AWorld);
  FHandle := NewtonCreateCompoundCollision(World.Handle, 0);

  FChilds := TPhysColliderArr.Create;
  FChilds.Capacity := AColliders.Count;

  NewtonCompoundCollisionBeginAddRemove(FHandle);
  for i := 0 to AColliders.Count - 1 do
  begin
    FChilds[i] := AColliders[i];
    node := NewtonCompoundCollisionAddSubCollision(FHandle, FChilds[i].Handle);
    NewtonCompoundCollisionSetSubCollisionMatrix(FHandle, node, @ATransforms[i]);
  end;
  NewtonCompoundCollisionEndAddRemove(FHandle);
end;

constructor TCollider_Compound.Create(const AWorld: TPhysWorld; const AColliders: array of IPhysCollider; const ATransforms: array of TMat4);
var node: Pointer;
  i: Integer;
begin
  Create(AWorld);
  FHandle := NewtonCreateCompoundCollision(World.Handle, 0);

  FChilds := TPhysColliderArr.Create;
  FChilds.Capacity := Length(AColliders);

  NewtonCompoundCollisionBeginAddRemove(FHandle);
  for i := 0 to Length(AColliders) - 1 do
  begin
    FChilds[i] := AColliders[i];
    node := NewtonCompoundCollisionAddSubCollision(FHandle, FChilds[i].Handle);
    NewtonCompoundCollisionSetSubCollisionMatrix(FHandle, node, @ATransforms[i]);
  end;
  NewtonCompoundCollisionEndAddRemove(FHandle);
end;

{ TJoint_UpConstraint }

function TJoint_UpConstraint.GetUpVector: TVec3;
begin
  NewtonUpVectorGetPin(FHandle, @Result);
end;

procedure TJoint_UpConstraint.SetUpVector(const AValue: TVec3);
begin
  NewtonUpVectorSetPin(FHandle, @AValue);
end;

function TJoint_UpConstraint.Body: IPhysBody;
begin
  Result := FBody;
end;

constructor TJoint_UpConstraint.Create(const AWorld: TPhysWorld; const ABody: IPhysBody; const AUp: TVec3);
begin
  Create(AWorld);
  FBody := ABody;
  FHandle := NewtonConstraintCreateUpVector(World.Handle, @AUp, ABody.Handle);
end;

{ TJoint }

function TJoint.Handle: NewtonJoint;
begin
  Result := FHandle;
end;

destructor TJoint.Destroy;
begin
  if FHandle <> nil then
  begin
    NewtonDestroyJoint(World.Handle, FHandle);
    FHandle := nil;
  end;
  inherited Destroy;
end;

{ TBody_Dynamic }

function TBody_Dynamic.GetMass: TVec4;
begin
  NewtonBodyGetMass(FHandle, @Result.w, @Result.x, @Result.y, @Result.z);
end;

function TBody_Dynamic.GetMassOrigin: TVec3;
begin
  NewtonBodyGetCentreOfMass(FHandle, @Result);
end;

procedure TBody_Dynamic.SetMass(const AValue: TVec4);
begin
  NewtonBodySetMassMatrix(FHandle, AValue.w, AValue.x, AValue.y, AValue.z);
end;

procedure TBody_Dynamic.SetMassOrigin(const AValue: TVec3);
begin
  NewtonBodySetCentreOfMass(FHandle, @AValue);
end;

constructor TBody_Dynamic.Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single);
var m: TVec4;
    origin: TVec3;
begin
  Create(AWorld);
  FCollider := ACollider;
  FHandle := NewtonCreateDynamicBody(World.Handle, ACollider.Handle, @ATransform);

  m.w := NewtonConvexCollisionCalculateVolume(ACollider.Handle) * ADensity;
  NewtonConvexCollisionCalculateInertialMatrix(ACollider.Handle, @m, @origin);
  SetMass(m);
  SetMassOrigin(origin);

  NewtonBodySetForceAndTorqueCallback(FHandle, @Callback_ApplyForceAndTorque);
end;

constructor TBody_Dynamic.Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4);
begin
  Create(AWorld);
  FCollider := ACollider;
  FHandle := NewtonCreateDynamicBody(World.Handle, ACollider.Handle, @ATransform);

  SetMass(AMass);
  SetMassOrigin(Vec(0,0,0));

  NewtonBodySetForceAndTorqueCallback(FHandle, @Callback_ApplyForceAndTorque);
end;

function TBody_Dynamic.Kind: TPhysBodyKind;
begin
  Result := bkDynamic;
end;

{ TBody_Static }

function TBody_Static.Kind: TPhysBodyKind;
begin
  Result := bkStatic;
end;

constructor TBody_Static.Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4);
begin
  Create(AWorld);
  FCollider := ACollider;
  FHandle := NewtonCreateDynamicBody(World.Handle, ACollider.Handle, @ATransform);
end;

{ TBody }

function TBody.Handle: NewtonBody;
begin
  Result := FHandle;
end;

function TBody.Collider: IPhysCollider;
begin
  Result := FCollider;
end;

function TBody.GetPos: TVec3;
begin
  NewtonBodyGetPosition(FHandle, @Result);
end;

function TBody.GetRot: TQuat;
begin
  NewtonBodyGetRotation(FHandle, @Result);
end;

function TBody.GetTransform: TMat4;
begin
  NewtonBodyGetMatrix(FHandle, @Result);
end;

procedure TBody.SetPos(const AValue: TVec3);
begin
  SetTransform( Mat4(GetRot, AValue) );
end;

procedure TBody.SetRot(const AValue: TQuat);
begin
  SetTransform( Mat4(AValue, GetPos) );
end;

procedure TBody.SetTransform(const AValue: TMat4);
begin
  NewtonBodySetMatrix(FHandle, @AValue);
end;

destructor TBody.Destroy;
begin
  if FHandle <> nil then
  begin
    NewtonDestroyBody(FHandle);
    FHandle := nil;
  end;
  inherited Destroy;
end;

procedure TBody.AfterConstruction;
var v: TVec3;
begin
  inherited AfterConstruction;
  NewtonBodySetUserData(FHandle, Self);
  v := Vec(0,0,0);
  NewtonBodySetVelocity(FHandle, @v);
  NewtonBodySetOmega(FHandle, @v);
end;

{ TPhysChild }

constructor TPhysChild.Create(const AWorld: TPhysWorld);
begin
  FWorld := AWorld;
  FWorldRef := AWorld;
end;

{ TPhysWorld }

procedure TPhysWorld.DoApplyForceAndTorque(ABody: TBody; timestep: dFloat; threadIndex: Integer);
var dynBody: TBody_Dynamic absolute ABody;
    f: TVec3;
begin
  if ABody is TBody_Dynamic then
  begin
    f := FGravity * dynBody.GetMass.w;
    NewtonBodyAddForce(ABody.FHandle, @f);
  end;
end;

function TPhysWorld.GetGravity: TVec3;
begin
  Result := FGravity;
end;

procedure TPhysWorld.SetGravity(const AValue: TVec3);
begin
  FGravity := AValue;
end;

function TPhysWorld.Handle: NewtonWorld;
begin
  Result := FWorld;
end;

function TPhysWorld.CreateCollider_Box(const ABoxSize: TVec3; const AOffset: TVec3): IPhysCollider_Box;
begin
  Result := TCollider_Box.Create(Self, ABoxSize, AOffset);
end;

function TPhysWorld.CreateCollider_Capsule(ARadius, ALengthX: Single; const AOffset: TVec3): IPhysCollider_Capsule;
begin
  Result := TCollider_Capsule.Create(Self, ARadius, ALengthX, AOffset);
end;

function TPhysWorld.CreateCollider_Compound(const AChildColliders: IPhysColliderArr): IPhysCollider_Compound;
begin
  Result := TCollider_Compound.Create(Self, AChildColliders);
end;

function TPhysWorld.CreateCollider_Compound(const AChildColliders: IPhysColliderArr; const ATransforms: array of TMat4): IPhysCollider_Compound;
begin
  Assert(AChildColliders.Count = Length(ATransforms));
  Result := TCollider_Compound.Create(Self, AChildColliders, ATransforms);
end;

function TPhysWorld.CreateCollider_Compound(const AChildColliders: array of IPhysCollider; const ATransforms: array of TMat4): IPhysCollider_Compound;
begin
  Assert(Length(AChildColliders) = Length(ATransforms));
  Result := TCollider_Compound.Create(Self, AChildColliders, ATransforms);
end;

function TPhysWorld.CreateBody_Static(const ACollider: IPhysCollider; const ATransform: TMat4): IPhysBody_Static;
begin
  Result := TBody_Static.Create(Self, ACollider, ATransform);
end;

function TPhysWorld.CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single): IPhysBody_Dynamic;
begin
  Result := TBody_Dynamic.Create(Self, ACollider, ATransform, ADensity);
end;

function TPhysWorld.CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4): IPhysBody_Dynamic;
begin
  Result := TBody_Dynamic.Create(Self, ACollider, ATransform, AMass);
end;

function TPhysWorld.CreateJoint_UpConstraint(const ABody: IPhysBody; const AUpVector: TVec3): IPhysJoint_UpConstraint;
begin
  Result := TJoint_UpConstraint.Create(Self, ABody, AUpVector);
end;

procedure TPhysWorld.UpdateStep(AIntervalMSec: Integer);
begin
  NewtonUpdate(FWorld, AIntervalMSec*1000); //todo async
end;

constructor TPhysWorld.Create;
begin
  FWorld := NewtonCreate();
  NewtonSetSolverModel(FWorld, 1);
  FGravity := Vec(0, -9.81, 0);
end;

destructor TPhysWorld.Destroy;
begin
  NewtonDestroyAllBodies(FWorld);
  NewtonDestroy(FWorld);
  FWorld := nil;
  inherited Destroy;
end;

end.

