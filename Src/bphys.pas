unit bPhys;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, avContnrs, mutils, Newton;

type
  TPhysColliderKind = (ckBox);

  IPhysCollider = interface
  ['{6D35EC76-E9F4-41D8-9098-4EC61DD7DF9B}']
    function Handle: NewtonCollision;
    function Kind: TPhysColliderKind;
  end;

  IPhysCollider_Box = interface (IPhysCollider)
  ['{D4E8BD0C-6806-4D2E-A747-8ED2DA711557}']
    function Size  : TVec3;
    function Offset: TVec3;
  end;

  IPhysMaterial = interface
  ['{8190FC7D-0B59-47CC-9719-F205368CB69F}']
  end;

  TPhysBodyKind = (bkStatic, bkDynamic, bkKinematic);

  { IPhysBody }

  IPhysBody = interface
  ['{895B1B00-DEC1-4222-9774-038A37C9B829}']
    function GetTransform: TMat4;
    procedure SetTransform(const AValue: TMat4);

    function Collider: IPhysCollider;
    function Kind: TPhysBodyKind;

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

  { IPhysWorld }

  IPhysWorld = interface
  ['{3F3046BB-8A43-4049-9724-579DA87ED453}']
    function GetGravity: TVec3;
    procedure SetGravity(const AValue: TVec3);

    function Handle: NewtonWorld;

    function CreateCollider_Box(const ABoxSize: TVec3; const AOffset: TVec3): IPhysCollider_Box;

    function CreateBody_Static(const ACollider: IPhysCollider; const ATransform: TMat4): IPhysBody_Static;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single): IPhysBody_Dynamic; overload;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4): IPhysBody_Dynamic; overload;

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

  TMaterial = class (TPhysChild, IPhysMaterial)
  private
  public
  end;

  { TPhysBody }

  TPhysBody = class (TPhysChild, IPhysBody)
  protected
    FHandle: NewtonBody;
    FCollider: IPhysCollider;
    function Collider: IPhysCollider;
    function Kind: TPhysBodyKind; virtual; abstract;

    function GetTransform: TMat4;
    procedure SetTransform(const AValue: TMat4);
  public
    destructor Destroy; override;
    procedure AfterConstruction; override;
  end;

  { TPhysBody_Static }

  TPhysBody_Static = class (TPhysBody, IPhysBody_Static)
  protected
    function Kind: TPhysBodyKind; override;
  public
    constructor Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4); overload;
  end;

  { TPhysBody_Dynamic }

  TPhysBody_Dynamic = class (TPhysBody, IPhysBody_Dynamic)
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

  { TPhysWorld }

  TPhysWorld = class (TInterfacedObject, IPhysWorld)
  private
    FGravity: TVec3;
    FWorld: NewtonWorld;

    procedure DoApplyForceAndTorque(ABody: TPhysBody; timestep : dFloat; threadIndex : Integer);
  private
    function GetGravity: TVec3;
    procedure SetGravity(const AValue: TVec3);

    function Handle: NewtonWorld;

    function CreateCollider_Box(const ABoxSize: TVec3; const AOffset: TVec3): IPhysCollider_Box;

    function CreateBody_Static(const ACollider: IPhysCollider; const ATransform: TMat4): IPhysBody_Static;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single): IPhysBody_Dynamic; overload;
    function CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4): IPhysBody_Dynamic; overload;

    procedure UpdateStep(AIntervalMSec: Integer);
  public
    constructor Create();
    destructor Destroy; override;
  end;

procedure Callback_ApplyForceAndTorque(const body : NewtonBody; timestep : dFloat; threadIndex : Integer); cdecl;
var obj: TPhysBody;
begin
  obj := TPhysBody(NewtonBodyGetUserData(body));
  obj.World.DoApplyForceAndTorque(obj, timestep, threadIndex);
end;

function Create_IPhysWorld: IPhysWorld;
begin
  Result := TPhysWorld.Create();
end;

{ TPhysBody_Dynamic }

function TPhysBody_Dynamic.GetMass: TVec4;
begin
  NewtonBodyGetMassMatrix(FHandle, @Result.w, @Result.x, @Result.y, @Result.z);
end;

function TPhysBody_Dynamic.GetMassOrigin: TVec3;
begin
  NewtonBodyGetCentreOfMass(FHandle, @Result);
end;

procedure TPhysBody_Dynamic.SetMass(const AValue: TVec4);
begin
  NewtonBodySetMassMatrix(FHandle, AValue.w, AValue.x, AValue.y, AValue.z);
end;

procedure TPhysBody_Dynamic.SetMassOrigin(const AValue: TVec3);
begin
  NewtonBodySetCentreOfMass(FHandle, @AValue);
end;

constructor TPhysBody_Dynamic.Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single);
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

constructor TPhysBody_Dynamic.Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4);
begin
  Create(AWorld);
  FCollider := ACollider;
  FHandle := NewtonCreateDynamicBody(World.Handle, ACollider.Handle, @ATransform);

  SetMass(AMass);
  SetMassOrigin(Vec(0,0,0));

  NewtonBodySetForceAndTorqueCallback(FHandle, @Callback_ApplyForceAndTorque);
end;

function TPhysBody_Dynamic.Kind: TPhysBodyKind;
begin
  Result := bkDynamic;
end;

{ TPhysBody_Static }

function TPhysBody_Static.Kind: TPhysBodyKind;
begin
  Result := bkStatic;
end;

constructor TPhysBody_Static.Create(const AWorld: TPhysWorld; const ACollider: IPhysCollider; const ATransform: TMat4);
begin
  Create(AWorld);
  FCollider := ACollider;
  FHandle := NewtonCreateDynamicBody(World.Handle, ACollider.Handle, @ATransform);
end;

{ TPhysBody }

function TPhysBody.Collider: IPhysCollider;
begin
  Result := FCollider;
end;

function TPhysBody.GetTransform: TMat4;
begin
  NewtonBodyGetMatrix(FHandle, @Result);
end;

procedure TPhysBody.SetTransform(const AValue: TMat4);
begin
  NewtonBodySetMatrix(FHandle, @AValue);
end;

destructor TPhysBody.Destroy;
begin
  if FHandle <> nil then
  begin
    NewtonDestroyBody(World.Handle, FHandle);
    FHandle := nil;
  end;
  inherited Destroy;
end;

procedure TPhysBody.AfterConstruction;
begin
  inherited AfterConstruction;
  NewtonBodySetUserData(FHandle, Self);
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

{ TPhysChild }

constructor TPhysChild.Create(const AWorld: TPhysWorld);
begin
  FWorld := AWorld;
  FWorldRef := AWorld;
end;

{ TPhysWorld }

procedure TPhysWorld.DoApplyForceAndTorque(ABody: TPhysBody; timestep: dFloat; threadIndex: Integer);
var dynBody: TPhysBody_Dynamic absolute ABody;
    f: TVec3;
begin
  if ABody is TPhysBody_Dynamic then
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

function TPhysWorld.CreateBody_Static(const ACollider: IPhysCollider; const ATransform: TMat4): IPhysBody_Static;
begin
  Result := TPhysBody_Static.Create(Self, ACollider, ATransform);
end;

function TPhysWorld.CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; ADensity: Single): IPhysBody_Dynamic;
begin
  Result := TPhysBody_Dynamic.Create(Self, ACollider, ATransform, ADensity);
end;

function TPhysWorld.CreateBody_Dynamic(const ACollider: IPhysCollider; const ATransform: TMat4; const AMass: TVec4): IPhysBody_Dynamic;
begin
  Result := TPhysBody_Dynamic.Create(Self, ACollider, ATransform, AMass);
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
  inherited Destroy;
end;

end.

