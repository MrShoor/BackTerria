unit gMainMenu;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, avMiniControls;

type

  { TDefButton }

  TDefButton = class (TavmCustomButton)
  protected
    procedure DoValidate; override;
  end;

  { TDefPanel }

  TDefPanel = class (TavmCustomControl)
  protected
    procedure DoValidate; override;
  end;

  { TgMainMenu }

  TgMainMenu = class
  private
  public
    procedure AfterDraw;
  end;

implementation

{ TgMainMenu }

procedure TgMainMenu.AfterDraw;
begin

end;

{ TDefPanel }

procedure TDefPanel.DoValidate;
begin
  inherited DoValidate;
end;

{ TDefButton }

procedure TDefButton.DoValidate;
begin
  inherited DoValidate;
end;

end.

