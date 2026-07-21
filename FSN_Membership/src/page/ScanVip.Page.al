page 50082 "FSN Scan VIP"
{
    Caption = 'Escanear VIP';
    PageType = NavigatePage;
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            usercontrol(ScanVip; ScanVip)
            {
                ApplicationArea = All;
                trigger Onload()
                begin
                    //Message('Page loaded!!!');
                end;

                trigger RecivedDataToAL(inputText: Text)
                var
                    longitudVIP: Integer;
                begin
                    //CurrPage.ScanVip.GetVIP();
                    longitudVIP := 0;
                    Codigo := inputText;

                    longitudVIP := StrLen(Codigo);
                    if (longitudVIP > 20) then begin
                        Message('El número de caracteres no es válida: ' + Format(longitudVIP));
                        Codigo := '';
                    end;

                    CurrPage.Close();
                end;

                trigger OnCancel()
                begin
                    codigo := '';
                    CurrPage.Close();
                end;

                trigger OnTimeOut(txt: Text)
                begin
                    Codigo := txt;
                    Error('Debe escanear el código VIP.');
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        Codigo: Text;

    procedure GetCodigoVIP(): Text
    begin
        CurrPage.RunModal();
        exit(Codigo);
    end;
}

