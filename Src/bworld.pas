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
  bTypes;

type
  TbWorld = class;

  { TbGameObject }

  TbGameObject = class (TWeakedObject)
  private
    FBBox: TAABB;

    FPos: TVec3;
    FRot: TQuat;
    FScale: Single;
    FTransformValid: Boolean;
    FTransform: TMat4;
    FTransformInv: TMat4;

    FWorld: TbWorld;
    procedure SetBBox(const AValue: TAABB);
    procedure SetPos(const AValue: TVec3);
    procedure SetRot(const AValue: TQuat);
    procedure SetScale(const AValue: Single);

    procedure ValidateTransform;
  protected
    procedure SubscribeForUpdateStep;
    procedure UnSubscribeFromUpdateStep;
    procedure UpdateStep; virtual;
  public
    property Pos  : TVec3  read FPos   write SetPos;
    property Rot  : TQuat  read FRot   write SetRot;
    property Scale: Single read FScale write SetScale;
    property BBox : TAABB  read FBBox  write SetBBox;

    function Transform(): TMat4;
    function TransformInv(): TMat4;

    constructor Create(const AWorld: TbWorld); virtual;
    destructor Destroy; override;
  end;
  TbGameObjArr = {$IfDef FPC}specialize{$EndIf}TArray<TbGameObject>;
  IbGameObjArr = {$IfDef FPC}specialize{$EndIf}IArray<TbGameObject>;
  TbGameObjSet = {$IfDef FPC}specialize{$EndIf}THashSet<TbGameObject>;
  IbGameObjSet = {$IfDef FPC}specialize{$EndIf}IHashSet<TbGameObject>;
  TbGameObjClass = class of TbGameObject;

  { TbWorld }

  TbWorld = class (TWeakedObject)
  private
    FObjects   : IbGameObjSet;
    FToDestroy : IbGameObjSet;
    FUpdateSubs: IbGameObjSet;
    FTempObjs  : IbGameObjArr;

    FTimeTick: Int64;
  public
    procedure UpdateStep();
    procedure SafeDestroy(const AObj: TbGameObject);
    procedure ProcessToDestroy;
  end;

implementation

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

constructor TbGameObject.Create(const AWorld: TbWorld);
begin
  FScale := 1;
  FRot.v4 := Vec(0,0,0,1);
  FBBox := EmptyAABB;

  FWorld := AWorld;
  if FWorld <> nil then
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

end.

