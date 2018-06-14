unit bFPVCamera;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, avRes, mutils;

type

  { TbFPVCamera }

  TbFPVCamera = class(TavMainRenderChild)
  private
    FPitch: Single;
    FPos: TVec3;
    FYaw: Single;
    function GetDirection: TVec3;
    procedure SetPitch(const AValue: Single);
    procedure SetPos(const AValue: TVec3);
    procedure SetYaw(const AValue: Single);
  public
    property Yaw: Single read FYaw write SetYaw;
    property Pitch: Single read FPitch write SetPitch;

    property Dir: TVec3 read GetDirection;
    property Pos: TVec3 read FPos write SetPos;
  end;

implementation

{ TbFPVCamera }

procedure TbFPVCamera.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
  Main.Camera.Eye := AValue;
  Main.Camera.At := Main.Camera.Eye + Dir;
end;

procedure TbFPVCamera.SetPitch(const AValue: Single);
const E = 0.001;
begin
  if FPitch = AValue then Exit;
  FPitch := Clamp(AValue, -Pi * 0.5 + E, Pi * 0.5 - E);

  Main.Camera.At := Main.Camera.Eye + Dir;
end;

function TbFPVCamera.GetDirection: TVec3;
var p: Single;
    sn_p, cs_p: Single;
begin
  p := Pi * 0.5 - FPitch;
  sn_p := sin(p);
  cs_p := cos(p);
  Result.x := sn_p * cos(Pi*0.5 - FYaw);
  Result.z := sn_p * sin(Pi*0.5 - FYaw);
  Result.y := cs_p;
end;

procedure TbFPVCamera.SetYaw(const AValue: Single);
begin
  if FYaw = AValue then Exit;
  FYaw := AValue;

  Main.Camera.At := Main.Camera.Eye + Dir;
end;

end.

