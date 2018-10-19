unit bGraphicalObjects;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, bWorld, avRes, avBase, avTypes, mutils, avCanvas;

type
  { TbGraphicalObject }

  TbGraphicalObject = class (TavMainRenderChild)
  private
    FPos: TVec3;
    FCanvas: TavCanvas;
    function GetPos: TVec3;
    procedure SetPos(const AValue: TVec3);
  protected
    FWorld: TbWorld;
    function CanRegister(target: TavObject): boolean; override;
  public
    property World: TbWorld read FWorld;
    property Pos  : TVec3 read GetPos write SetPos;

    property Canvas: TavCanvas read FCanvas;

    procedure Draw(); virtual;

    procedure AfterConstruction; override;
  end;

implementation

{ TbGraphicalObject }

function TbGraphicalObject.GetPos: TVec3;
begin
  Result := FPos;
end;

procedure TbGraphicalObject.SetPos(const AValue: TVec3);
begin
  if FPos = AValue then Exit;
  FPos := AValue;
end;

function TbGraphicalObject.CanRegister(target: TavObject): boolean;
begin
  Result := inherited CanRegister(target);
  if not Result then Exit;
  FWorld := TbWorld(target.FindAtParents(TbWorld));
  Result := Assigned(FWorld);
end;

procedure TbGraphicalObject.Draw;
var pp: TVec4;
    range: TVec2;
begin
  pp := Vec(FPos, 1.0) * Main.Camera.Matrix * Main.Projection.Matrix;
  pp.xyz := pp.xyz / pp.w;
  range := Main.Projection.DepthRangeMinMax;
  if (pp.z < range.x) or (pp.z > range.y) then Exit;

  pp.xy := (pp.xy*0.5 + Vec(0.5, 0.5)) * Main.WindowSize;

  FCanvas.ZValue := pp.z;
  FCanvas.Draw(0, pp.xy, 1);
end;

procedure TbGraphicalObject.AfterConstruction;
begin
  inherited AfterConstruction;
  FCanvas := TavCanvas.Create(Self);
end;

end.

