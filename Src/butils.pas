unit bUtils;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, mutils;

type
  TPathPos = record
    Idx: Integer;
    Pos: Single;
  end;

function TravelByPath(const APath: array of TVec3; ADistance: Single; var APathPos: TPathPos; ALoop: Boolean = True): TVec3;
function PosAtPath(const APath: array of TVec3; const APathPos: TPathPos): TVec3;

implementation

procedure TravelByPath_Internal(const APath: array of TVec3; ADistance: Single; var APathPos: TPathPos; ALoop: Boolean);
var pt1, pt2, dir: TVec3;
    dirLen: Single;
    dirLeft: Single;
begin
  pt1 := APath[APathPos.Idx];
  pt2 := APath[APathPos.Idx + 1];
  dir := pt2 - pt1;
  dirLen := Len(dir);
  dirLeft := (1-APathPos.Pos)*dirLen;

  if dirLeft > ADistance then
  begin
    APathPos.Pos := APathPos.Pos + ADistance/dirLen;
    if APathPos.Pos >= 1 then
    begin
      if APathPos.Idx < Length(APath) - 2 then
      begin
        Inc(APathPos.Idx);
        APathPos.Pos := 0;
      end
      else
      begin
        if ALoop then
        begin
          APathPos.Idx := 0;
          APathPos.Pos := 0;
        end
        else
          APathPos.Pos := 1;
      end;
    end;
  end
  else
  begin
    if APathPos.Idx = Length(APath) - 2 then
    begin
      if ALoop then
      begin
        APathPos.Idx := 0;
        APathPos.Pos := 0;
        TravelByPath_Internal(APath, ADistance - dirLeft, APathPos, ALoop);
      end
      else
        APathPos.Pos := 1;
    end
    else
    begin
      Inc(APathPos.Idx);
      APathPos.Pos := 0;
      TravelByPath_Internal(APath, ADistance - dirLeft, APathPos, ALoop);
    end;
  end;
end;

function TravelByPath(const APath: array of TVec3; ADistance: Single; var APathPos: TPathPos; ALoop: Boolean): TVec3;
begin
  TravelByPath_Internal(APath, ADistance, APathPos, ALoop);
  Result := PosAtPath(APath, APathPos);
end;

function PosAtPath(const APath: array of TVec3; const APathPos: TPathPos): TVec3;
begin
  Result := Lerp(APath[APathPos.Idx], APath[APathPos.Idx+1], APathPos.Pos);
end;

end.

