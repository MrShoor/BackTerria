unit bAutoColliders;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, avContnrs, mutils, intfUtils;

type
  ICollider = interface;

  TColliderKind = (ckBox, ckCylinder);
  TColliderType = (ctStatic, ctDynamic, ctSensor);

  TCollisionFilterMode = (cmDefault, cmAsSensor, cmNone);

  TOnCollisionFilter = function (const ACurrent, AOther: ICollider): TCollisionFilterMode of object;

  { ICollider }

  ICollider = interface
  ['{C0226B74-6AC8-4046-8127-748E266D3926}']
    function  GetApplyGravity: Boolean;
    function  GetPos: TVec3;
    function  GetVel: TVec3;
    function  GetUserData: Pointer;
    function  GetFilter: TOnCollisionFilter;
    procedure SetApplyGravity(const AValue: Boolean);
    procedure SetPos(const AValue: TVec3);
    procedure SetVel(const AValue: TVec3);
    procedure SetUserData(const AValue: Pointer);
    procedure SetFilter(const AValue: TOnCollisionFilter);

    function AABB: TAABB;
    function ColKind: TColliderKind;
    function ColType: TColliderType;

    property Pos: TVec3 read GetPos write SetPos;
    property Vel: TVec3 read GetVel write SetVel;
    property ApplyGravity: Boolean read GetApplyGravity write SetApplyGravity;
    property UserData: Pointer read GetUserData write SetUserData;

    property Filter: TOnCollisionFilter read GetFilter write SetFilter;
  end;
  IColliderArr = {$IfDef FPC}specialize{$EndIf} IArray<ICollider>;
  TColliderArr = {$IfDef FPC}specialize{$EndIf} TArray<ICollider>;

  { ICollider_Box }

  ICollider_Box = interface (ICollider)
  ['{225FE8BB-8049-4A16-8C0E-EB7E0D342901}']
    function  GetSize: TVec3;
    procedure SetSize(const AValue: TVec3);

    property Size: TVec3 read GetSize write SetSize;
  end;

  { ICollider_Cylinder }

  ICollider_Cylinder = interface (ICollider)
  ['{3720CD09-9E63-4E4F-BBF5-67A0C47E26C9}']
    function  GetHeight: Single;
    function  GetRadius: Single;
    procedure SetHeight(const AValue: Single);
    procedure SetRadius(const AValue: Single);

    property Radius: Single read GetRadius write SetRadius;
    property Height: Single read GetHeight write SetHeight;
  end;

  TIteratorCallback = procedure (const collider: ICollider) of object;

  ICollisionNotifications = interface (IWeakedInterface)
  ['{0526E7B6-FF41-4136-9737-054C32255FDD}']
    procedure OnCollision(const ACollider: ICollider);
  end;

  IAllCollisionsNotifications = interface (IWeakedInterface)
  ['{0526E7B6-FF41-4136-9737-054C32255FDD}']
    procedure OnCollision(const ACollider1, ACollider2: ICollider);
  end;

  TOnCollision = procedure (const ACollider: ICollider) of object;

  TCollisionNotifications = class (TWeakedInterfacedObject, ICollisionNotifications)
  private
    FCallback: TOnCollision;
    procedure OnCollision(const ACollider: ICollider);
  public
    constructor Create(const ACallback: TOnCollision);
  end;

  TOnAllCollisions = procedure (const ACollider1, ACollider2: ICollider) of object;

  TAllCollisionNotifications = class (TWeakedInterfacedObject, IAllCollisionsNotifications)
  private
    FCallback: TOnAllCollisions;
    procedure OnCollision(const ACollider1, ACollider2: ICollider);
  public
    constructor Create(const ACallback: TOnAllCollisions);
  end;

  { IAutoCollidersGroup }

  IAutoCollidersGroup = interface
  ['{BB240EB1-02CA-47D3-867F-A7BB6C85E54E}']
    function GetGravity: TVec3;
    procedure SetGravity(const AValue: TVec3);

    procedure UpdateStep(const AInterval: Integer);

    function Create_Box(const ASize, APos: TVec3; AType: TColliderType): ICollider_Box;
    function Create_Cylinder(ARadius, AHeight: Single; const APos: TVec3; AType: TColliderType): ICollider_Cylinder;

    procedure SubscribeOnCollision(const ACollider: ICollider; const ASubscriber: ICollisionNotifications);
    procedure SubscribeOnAllCollisions(const ASubscriber: IAllCollisionsNotifications);

    procedure EnumColliders(const ABox: TAABB; const ACallback: TIteratorCallback); overload;
    function QueryColliders(const ABox: TAABB): IColliderArr; overload;

    property Gravity: TVec3 read GetGravity write SetGravity;
  end;

function Create_IAutoCollidersGroup: IAutoCollidersGroup;

implementation

uses
  Math;

type
  TCollider = class;
  TAutoCollidersGroup = class;

  ICollidersTree = {$IfDef FPC}specialize{$EndIf} ILooseOctTree<TCollider>;
  TCollidersTree = {$IfDef FPC}specialize{$EndIf} TLooseOctTree<TCollider>;

  ICollidersTreeNode = {$IfDef FPC}specialize{$EndIf} IBase_LooseTreeNode<TCollider, TAABB>;

  ICollider_Internal = interface
  ['{4B4A34BA-8FA0-4472-8231-C392CC775A55}']
    function GetObject(): TCollider;
  end;

  { TCollider }

  TCollider = class(TInterfacedObject, ICollider, ICollider_Internal)
  private
    FApplyGravity: Boolean;
    FOwner: TAutoCollidersGroup;
    FPos: TVec3;
    FVel: TVec3;
    FColType: TColliderType;
    FUserData: Pointer;
    FFilter: TOnCollisionFilter;
    function  GetApplyGravity: Boolean;
    function  GetPos: TVec3;
    function  GetVel: TVec3;
    function  GetUserData: Pointer;
    function  GetFilter: TOnCollisionFilter;
    procedure SetApplyGravity(const AValue: Boolean);
    procedure SetPos(const AValue: TVec3);
    procedure SetVel(const AValue: TVec3);
    procedure SetUserData(const AValue: Pointer);
    procedure SetFilter(const AValue: TOnCollisionFilter);

    function GetObject(): TCollider;
  protected
    procedure UpdateInTree;
    function AABB: TAABB; virtual; abstract;
    function ColKind: TColliderKind; virtual; abstract;
    function ColType: TColliderType;

    property Pos: TVec3 read GetPos write SetPos;
    property Vel: TVec3 read GetVel write SetVel;
    property ApplyGravity: Boolean read GetApplyGravity write SetApplyGravity;
  public
    constructor Create(AOwner: TAutoCollidersGroup; AType: TColliderType; const APos: TVec3); overload;
    destructor Destroy; override;
  end;

  { TCollider_Box }

  TCollider_Box = class(TCollider, ICollider_Box)
  private
    FSize: TVec3;
    function  GetSize: TVec3;
    procedure SetSize(const AValue: TVec3);
  protected
    function AABB: TAABB; override;
    function ColKind: TColliderKind; override;
  public
    constructor Create(AOwner: TAutoCollidersGroup; AType: TColliderType; const APos, ASize: TVec3); overload;
  end;

  { TCollider_Cylinder }

  TCollider_Cylinder = class(TCollider, ICollider_Cylinder)
  private
    FRadius: Single;
    FHeight: Single;
    function  GetHeight: Single;
    function  GetRadius: Single;
    procedure SetHeight(const AValue: Single);
    procedure SetRadius(const AValue: Single);
  protected
    function AABB: TAABB; override;
    function ColKind: TColliderKind; override;
  public
    constructor Create(AOwner: TAutoCollidersGroup; AType: TColliderType; const APos: TVec3; ARadius, AHeight: Single); overload;
  end;

  TAllCollisionPublisher = class (TPublisherBase, IAllCollisionsNotifications)
  private
    procedure OnCollision(const ACollider1, ACollider2: ICollider);
  end;
  TCollisionPublisher = class (TPublisherBase, ICollisionNotifications)
  private
    procedure OnCollision(const ACollider: ICollider);
  end;

  { TAutoCollidersGroup }

  TAutoCollidersGroup = class (TInterfacedObject, IAutoCollidersGroup, ILooseNodeCallBackIterator)
  private type
    THit = record
      col1: ICollider;
      col2: ICollider;
      dir1: TVec3;
      dir2: TVec3;
    end;
    PHit = ^THit;
    IHitArr = {$IfDef FPC}specialize{$EndIf}IArray<THit>;
    THitArr = {$IfDef FPC}specialize{$EndIf}TArray<THit>;

    IColliderSet = {$IfDef FPC}specialize{$EndIf} IHashSet<TCollider>;
    TColliderSet = {$IfDef FPC}specialize{$EndIf} THashSet<TCollider>;

    IParticularCollidersPublisher = {$IfDef FPC}specialize{$EndIf} IHashMap<TCollider, ICollisionNotifications>;
    TParticularCollidersPublisher = {$IfDef FPC}specialize{$EndIf} THashMap<TCollider, ICollisionNotifications>;

    TRefCleaner = class(TInterfacedObject, ILooseNodeCallBackIterator)
    private
      procedure OnEnumNode(const ASender: IInterface; const ANode: IInterface; var EnumChilds: Boolean);
    end;

  private
    FGravity: TVec3;
    FTree: ICollidersTree;

    FDynamicColliders: IColliderSet;
    FSensorColliders: IColliderSet;

    FWakedColliders: IColliderSet;
    FOldWakedColliders: IColliderSet;

    FAllCollidersPublisher: IAllCollisionsNotifications;
    FParticularCollidersPublisher: IParticularCollidersPublisher;
  private
    FQueryBox: TAABB;
    FQueryCallback: TIteratorCallback;
    procedure OnEnumNode(const ASender: IInterface; const ANode: IInterface; var EnumChilds: Boolean);
  private
    FCurrentCollider: ICollider;
    FHits: IHitArr;
    procedure AddHit(const AC1, AC2: ICollider; const ADir1, ADir2: TVec3);
    procedure ResolveCollision(const AOtherCollider: ICollider);
  private
    FQueryResult: IColliderArr;
    procedure AddToQueryResult(const ACollider: ICollider);
  public
    function GetGravity: TVec3;
    procedure SetGravity(const AValue: TVec3);

    procedure AddToWake(const ACollider: TCollider);
    procedure UpdateStep(const AInterval: Integer);
    procedure ResolveCollisions;

    function Create_Box(const ASize, APos: TVec3; AType: TColliderType): ICollider_Box;
    function Create_Cylinder(ARadius, AHeight: Single; const APos: TVec3; AType: TColliderType): ICollider_Cylinder;

    procedure SubscribeOnCollision(const ACollider: ICollider; const ASubscriber: ICollisionNotifications);
    procedure SubscribeOnAllCollisions(const ASubscriber: IAllCollisionsNotifications);

    procedure EnumColliders(const ABox: TAABB; const ACallback: TIteratorCallback); overload;
    function  QueryColliders(const ABox: TAABB): IColliderArr; overload;

    constructor Create;
    destructor Destroy; override;
  end;

function EvaluatePushVector(const B1, B2: ICollider_Box): TVec3; overload;
var dir: TVec3;
    push: TVec3;
begin
  Result := Vec(0,0,0);
  if not Intersect(B1.AABB, B2.AABB) then Exit;

  dir := B1.Pos - B2.Pos;
  push := Abs(dir) - B1.Size * 0.5 - B2.Size * 0.5;
  if push.x > push.y then
  begin
    if push.x > push.z then
      Result := Vec(-push.x*sign(dir.x),0,0)
    else
      Result := Vec(0,0,-push.z*sign(dir.z));
  end
  else
  begin
    if push.y > push.z then
      Result := Vec(0,-push.y*sign(dir.y),0)
    else
      Result := Vec(0,0,-push.z*sign(dir.z));
  end;
end;

function EvaluatePushVector(const B: ICollider_Box; const C: ICollider_Cylinder): TVec3; overload;
var dir: TVec3;
    dirXZ: TVec2;
    dirXZLen: Single;
    push: TVec3;
    bsize: TVec3;
    r: Single;
begin
  Result := Vec(0,0,0);

  dir := B.Pos - C.Pos;
  bsize := B.Size * 0.5;
  r := C.Radius;

  push := Abs(dir);
  push.y := push.y - C.Height * 0.5 - bsize.y;
  if push.y >= 0 then Exit;

  push.x := push.x - bsize.x;
  if push.x > r then Exit;
  push.z := push.z - bsize.z;
  if push.z > r then Exit;
  if sqr(max(0, push.x)) + sqr(max(0, push.z)) > sqr(r) then Exit;

  if push.x <= 0 then
  begin
    if push.z < 0 then
    begin
      dirXZ := SetLen(Vec(dir.x, dir.z), r);
      push.x := abs(push.x)*sign(dir.x) + dirXZ.x;
      push.z := abs(push.z)*sign(dir.z) + dirXZ.y;
    end
    else
    begin
      push.z := (push.z - r) * sign(dir).z;
      push.x := 0;
    end;
  end
  else
  begin
    if push.z <= 0 then
    begin
      push.x := (push.x - r) * sign(dir).x;
      push.z := 0;
    end
    else
    begin
      dirXZ := Vec(push.x, push.z);
      dirXZLen := Len(dirXZ);
      dirXZ := dirXZ/dirXZLen * (r - dirXZLen);
      push.x := dirXZ.x * sign(dir.x);
      push.z := dirXZ.y * sign(dir.z);
    end;
  end;

  if LenSqr(Vec(push.x, push.z)) > sqr(push.y) then
    Result := Vec(0, -push.y*sign(dir.y), 0)
  else
    Result := Vec(push.x, 0, push.z);
end;

function EvaluatePushVector(const C1, C2: ICollider_Cylinder): TVec3; overload;
var dir: TVec3;
    pushByHeight: Single;
    pushByRad: Single;
    dirLenXZ: Single;
begin
  Result := Vec(0,0,0);

  dir := C1.Pos - C2.Pos;
  pushByHeight := Abs(dir.Y) - (C1.Height + C2.Height) * 0.5;
  if pushByHeight >= 0 then Exit;
  dirLenXZ := Len(Vec(dir.x, dir.z));
  pushByRad := dirLenXZ - C1.Radius - C2.Radius;
  if pushByRad >= 0 then Exit;
  if pushByHeight < pushByRad then
    Result := -Vec(dir.x/dirLenXZ, 0, dir.z/dirLenXZ)*pushByRad
  else
    Result := Vec(0, -pushByHeight*sign(dir.y), 0);
end;

function EvaluatePushVector(const A1, A2: ICollider): TVec3; overload;
begin
  Result := Vec(0,0,0);
  case A1.ColKind of
    ckBox :
      begin
        case A2.ColKind of
          ckBox      : Result := EvaluatePushVector(A1 as ICollider_Box, A2 as ICollider_Box);
          ckCylinder : Result := EvaluatePushVector(A1 as ICollider_Box, A2 as ICollider_Cylinder);
        end;
      end;
    ckCylinder:
      begin
        case A2.ColKind of
          ckBox      : Result := -EvaluatePushVector(A2 as ICollider_Box, A1 as ICollider_Cylinder);
          ckCylinder : Result :=  EvaluatePushVector(A1 as ICollider_Cylinder, A2 as ICollider_Cylinder);
        end;
      end;
  end;
end;

function Create_IAutoCollidersGroup: IAutoCollidersGroup;
begin
  Result := TAutoCollidersGroup.Create;
end;

{ TAutoCollidersGroup.TRefCleaner }

procedure TAutoCollidersGroup.TRefCleaner.OnEnumNode(const ASender: IInterface; const ANode: IInterface; var EnumChilds: Boolean);
var N: ICollidersTreeNode absolute ANode;
    i: Integer;
begin
  EnumChilds := True;
  for i := 0 to N.ItemsCount - 1 do
    (N.Item(i) as ICollider_Internal).GetObject().FOwner := nil;
end;

{ TCollisionPublisher }

procedure TCollisionPublisher.OnCollision(const ACollider: ICollider);
var
  lst: TSubsList;
  i: Integer;
  cb: ICollisionNotifications;
begin
  lst := GetSubsList;
  for i := 0 to Length(lst) - 1 do
    if Supports(lst[i], ICollisionNotifications, cb) then
      cb.OnCollision(ACollider);
end;

{ TAllCollisionPublisher }

procedure TAllCollisionPublisher.OnCollision(const ACollider1, ACollider2: ICollider);
var
  lst: TSubsList;
  i: Integer;
  cb: IAllCollisionsNotifications;
begin
  lst := GetSubsList;
  for i := 0 to Length(lst) - 1 do
    if Supports(lst[i], IAllCollisionsNotifications, cb) then
      cb.OnCollision(ACollider1, ACollider2);
end;

{ TAllCollisionNotifications }

procedure TAllCollisionNotifications.OnCollision(const ACollider1, ACollider2: ICollider);
begin
  FCallback(ACollider1, ACollider2);
end;

constructor TAllCollisionNotifications.Create(const ACallback: TOnAllCollisions);
begin
  Assert(Assigned(ACallback));
  FCallback := ACallback;
end;

{ TCollisionNotifications }

procedure TCollisionNotifications.OnCollision(const ACollider: ICollider);
begin
  FCallback(ACollider);
end;

constructor TCollisionNotifications.Create(const ACallback: TOnCollision);
begin
  Assert(Assigned(ACallback));
  FCallback := ACallback;
end;

{ TCollider_Cylinder }

function TCollider_Cylinder.GetHeight: Single;
begin
  Result := FHeight;
end;

function TCollider_Cylinder.GetRadius: Single;
begin
  Result := FRadius;
end;

procedure TCollider_Cylinder.SetHeight(const AValue: Single);
begin
  if FHeight = AValue then Exit;
  FHeight := AValue;
  UpdateInTree;
end;

procedure TCollider_Cylinder.SetRadius(const AValue: Single);
begin
  if FRadius = AValue then Exit;
  FRadius := AValue;
  UpdateInTree;
end;

function TCollider_Cylinder.AABB: TAABB;
var v: TVec3;
begin
  v := Vec(FRadius, FHeight*0.5, FRadius);
  Result.min := FPos - v;
  Result.max := FPos + v;
end;

function TCollider_Cylinder.ColKind: TColliderKind;
begin
  Result := ckCylinder;
end;

constructor TCollider_Cylinder.Create(AOwner: TAutoCollidersGroup; AType: TColliderType; const APos: TVec3; ARadius, AHeight: Single);
begin
  Create(AOwner, AType, APos);
  FRadius := ARadius;
  FHeight := AHeight;
  UpdateInTree;
end;

{ TCollider_Box }

function TCollider_Box.GetSize: TVec3;
begin
  Result := FSize;
end;

procedure TCollider_Box.SetSize(const AValue: TVec3);
begin
  if FSize = AValue then Exit;
  UpdateInTree;
end;

function TCollider_Box.AABB: TAABB;
begin
  Result.min := FPos - FSize*0.5;
  Result.max := Result.min + FSize;
end;

function TCollider_Box.ColKind: TColliderKind;
begin
  Result := ckBox;
end;

constructor TCollider_Box.Create(AOwner: TAutoCollidersGroup; AType: TColliderType; const APos, ASize: TVec3);
begin
  Create(AOwner, AType, APos);
  FSize := ASize;
  UpdateInTree;
end;

{ TCollider }

function TCollider.GetApplyGravity: Boolean;
begin
  Result := FApplyGravity;
end;

function TCollider.GetPos: TVec3;
begin
  Result := FPos;
end;

function TCollider.GetVel: TVec3;
begin
  Result := FVel;
end;

function TCollider.GetUserData: Pointer;
begin
  Result := FUserData;
end;

function TCollider.GetFilter: TOnCollisionFilter;
begin
  Result := FFilter;
end;

procedure TCollider.SetApplyGravity(const AValue: Boolean);
begin
  FApplyGravity := AValue;
end;

procedure TCollider.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
  UpdateInTree;
end;

procedure TCollider.SetVel(const AValue: TVec3);
begin
  if FVel = AValue then Exit;
  FVel := AValue;
end;

procedure TCollider.SetUserData(const AValue: Pointer);
begin
  FUserData := AValue;
end;

procedure TCollider.SetFilter(const AValue: TOnCollisionFilter);
begin
  FFilter := AValue;
end;

function TCollider.GetObject: TCollider;
begin
  Result := Self;
end;

procedure TCollider.UpdateInTree;
begin
//  FOwner.FTree.Delete(Self);
  FOwner.FTree.Add(Self, AABB);
  FOwner.AddToWake(Self);
end;

function TCollider.ColType: TColliderType;
begin
  Result := FColType;
end;

constructor TCollider.Create(AOwner: TAutoCollidersGroup; AType: TColliderType; const APos: TVec3);
begin
  FOwner := AOwner;
  FColType := AType;
  FPos := APos;
  case FColType of
    ctDynamic: begin
      FOwner.FDynamicColliders.AddOrSet(Self);
      FApplyGravity := True;
    end;
    ctSensor : FOwner.FSensorColliders.AddOrSet(Self);
  end;
end;

destructor TCollider.Destroy;
begin
  inherited Destroy;
  if FOwner <> nil then
  begin
    FOwner.FTree.Delete(Self);
    FOwner.FWakedColliders.Delete(Self);
    FOwner.FParticularCollidersPublisher.Delete(Self);
    case FColType of
      ctDynamic: FOwner.FDynamicColliders.Delete(Self);
      ctSensor : FOwner.FSensorColliders.Delete(Self);
    end;
  end;
end;

{ TAutoCollidersGroup }

procedure TAutoCollidersGroup.OnEnumNode(const ASender: IInterface; const ANode: IInterface; var EnumChilds: Boolean);
var N: ICollidersTreeNode absolute ANode;
    i: Integer;
begin
  EnumChilds := True;//Intersect(FQueryBox, FTree.AABB(ANode));
  for i := 0 to N.ItemsCount - 1 do
    FQueryCallback(N.Item(i));
end;

procedure TAutoCollidersGroup.ResolveCollision(const AOtherCollider: ICollider);
var vThis, vOther: TVec3;
    thisI: ICollider;
    thisColType, otherColType: TColliderType;

    s1, s2: string;
begin
  thisI := FCurrentCollider;
  if AOtherCollider = thisI then Exit;

  thisColType := thisI.ColType;
  otherColType := AOtherCollider.ColType;

  if Assigned(thisI.Filter) then
    case thisI.Filter(thisI, AOtherCollider) of
      cmNone: Exit;
      cmAsSensor:
        begin
          thisColType := ctSensor;
          otherColType := ctSensor;
        end;
    end;
  if Assigned(AOtherCollider.Filter) then
    case AOtherCollider.Filter(AOtherCollider, thisI) of
      cmNone: Exit;
      cmAsSensor:
        begin
          thisColType := ctSensor;
          otherColType := ctSensor;
        end;
    end;

  vThis := EvaluatePushVector(thisI, AOtherCollider);
  vOther := Vec(0,0,0);
  if LenSqr(vThis) > 0 then
  begin
    case thisColType of
      ctDynamic :
        case otherColType of
          ctDynamic:
            begin
              vThis := vThis * 0.5;
              vOther := -vThis;
            end;
          ctStatic: ;
          ctSensor: vThis := Vec(0,0,0);
        end;
      ctStatic :
        case otherColType of
          ctDynamic:
            begin
              vOther := -vThis;
              vThis := Vec(0,0,0);
            end;
          ctStatic: ;
          ctSensor: vThis := Vec(0,0,0);
        end;
      ctSensor :
        vThis := Vec(0,0,0);
    end;
    AddHit(thisI, AOtherCollider, vThis, vOther);
  end;
end;

procedure TAutoCollidersGroup.AddToQueryResult(const ACollider: ICollider);
begin
  FQueryResult.Add(ACollider);
end;

function TAutoCollidersGroup.GetGravity: TVec3;
begin
  Result := FGravity;
end;

procedure TAutoCollidersGroup.SetGravity(const AValue: TVec3);
begin
  FGravity := AValue;
end;

procedure TAutoCollidersGroup.AddToWake(const ACollider: TCollider);
begin
  FWakedColliders.AddOrSet(ACollider);
end;

procedure TAutoCollidersGroup.UpdateStep(const AInterval: Integer);
var col: TCollider;
    scaled_gravity: TVec3;
begin
  scaled_gravity := FGravity*(AInterval/1000);

  FDynamicColliders.Reset;
  while FDynamicColliders.Next(col) do
  begin
    if col.ApplyGravity then
      col.Vel := col.Vel + scaled_gravity;
    col.Pos := col.Pos + col.Vel;
  end;

  FSensorColliders.Reset;
  while FSensorColliders.Next(col) do
  begin
    if col.ApplyGravity then
      col.Vel := col.Vel + scaled_gravity;
    col.Pos := col.Pos + col.Vel;
  end;

  ResolveCollisions();
end;

procedure TAutoCollidersGroup.AddHit(const AC1, AC2: ICollider; const ADir1, ADir2: TVec3);
var hit: THit;
begin
  hit.col1 := AC1;
  hit.col2 := AC2;;
  hit.dir1 := ADir1;
  hit.dir2 := ADir2;
  FHits.Add(hit);
end;

procedure TAutoCollidersGroup.ResolveCollisions;

  function GetParticularPublisher(const ACollider: ICollider): ICollisionNotifications;
  begin
    if not FParticularCollidersPublisher.TryGetValue((ACollider as ICollider_Internal).GetObject(), Result) then Result := nil;
  end;

var tmp: IColliderSet;
    col: TCollider;
    i: Integer;
    ph: PHit;
    publisher: ICollisionNotifications;
begin
  tmp := FOldWakedColliders;
  FOldWakedColliders := FWakedColliders;
  FWakedColliders := tmp;
  FWakedColliders.Clear;

  FHits.Clear();
  FOldWakedColliders.Reset;
  while FOldWakedColliders.Next(col) do
  begin
    FCurrentCollider := col;
    EnumColliders(col.AABB, {$IfDef FPC}@{$EndIf}ResolveCollision);
  end;

  for i := 0 to FHits.Count - 1 do
  begin
    ph := FHits.PItem[i];

    FAllCollidersPublisher.OnCollision(ph^.col1, ph^.col2);

    publisher := GetParticularPublisher(ph^.col1);
    if Assigned(publisher) then publisher.OnCollision(ph^.col2);
    publisher := GetParticularPublisher(ph^.col2);
    if Assigned(publisher) then publisher.OnCollision(ph^.col1);

    ph^.col1.Vel := ph^.col1.Vel - Projection(ph^.col1.Vel, ph^.dir1);
    ph^.col2.Vel := ph^.col2.Vel - Projection(ph^.col2.Vel, ph^.dir2);

    ph^.col1.Pos := ph^.col1.Pos + ph^.dir1;
    ph^.col2.Pos := ph^.col2.Pos + ph^.dir2;
  end;
  FHits.Clear();
  FOldWakedColliders.Clear;
end;

function TAutoCollidersGroup.Create_Box(const ASize, APos: TVec3; AType: TColliderType): ICollider_Box;
begin
  Result := TCollider_Box.Create(Self, AType, APos, ASize);
end;

function TAutoCollidersGroup.Create_Cylinder(ARadius, AHeight: Single; const APos: TVec3; AType: TColliderType): ICollider_Cylinder;
begin
  Result := TCollider_Cylinder.Create(Self, AType, APos, ARadius, AHeight);
end;

procedure TAutoCollidersGroup.SubscribeOnCollision(const ACollider: ICollider; const ASubscriber: ICollisionNotifications);
  function ObtainPublisher(): ICollisionNotifications;
  var obj: TCollider;
  begin
    obj := (ACollider as ICollider_Internal).GetObject();
    if not FParticularCollidersPublisher.TryGetValue(obj, Result) then
    begin
      Result := TCollisionPublisher.Create();
      FParticularCollidersPublisher.Add(obj, Result);
    end;
  end;
begin
  (ObtainPublisher() as IPublisher).Subscribe(ASubscriber);
end;

procedure TAutoCollidersGroup.SubscribeOnAllCollisions(const ASubscriber: IAllCollisionsNotifications);
begin
  (FAllCollidersPublisher as IPublisher).Subscribe(ASubscriber);
end;

procedure TAutoCollidersGroup.EnumColliders(const ABox: TAABB; const ACallback: TIteratorCallback);
begin
  FQueryBox := ABox;
  FQueryCallback := ACallback;
  FTree.EnumNodes(Self);
end;

function TAutoCollidersGroup.QueryColliders(const ABox: TAABB): IColliderArr;
begin
  FQueryResult := TColliderArr.Create();
  Result := FQueryResult;
  EnumColliders(ABox, {$IfDef FPC}@{$EndIf}AddToQueryResult);
  FQueryResult := nil;
end;

constructor TAutoCollidersGroup.Create;
begin
  FGravity := Vec(0,-0.0981, 0);
  FTree := TCollidersTree.Create(Vec(1,1,1));

  FDynamicColliders := TColliderSet.Create();
  FSensorColliders := TColliderSet.Create();

  FWakedColliders := TColliderSet.Create();
  FOldWakedColliders := TColliderSet.Create();

  FAllCollidersPublisher := TAllCollisionPublisher.Create;
  FParticularCollidersPublisher := TParticularCollidersPublisher.Create;

  FHits := THitArr.Create();
end;

destructor TAutoCollidersGroup.Destroy;
var rc: ILooseNodeCallBackIterator;
begin
  rc := TRefCleaner.Create;
  FTree.EnumNodes(rc);
  inherited Destroy;
end;

end.

