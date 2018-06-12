unit bLevel;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, bWorld, avRes;

type

  { TbLevel }

  TbLevel = class (TavMainRenderChild)
  public
    procedure BeforeDraw; virtual;
    procedure AfterDraw; virtual;
  end;
  TbLevelClass = class of TbLevel;

implementation

{ TbLevel }

procedure TbLevel.BeforeDraw;
begin

end;

procedure TbLevel.AfterDraw;
begin

end;

end.

