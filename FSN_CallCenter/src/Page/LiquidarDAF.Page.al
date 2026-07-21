page 50092 "FSN Liquidar DAF"
{
    PageType = Card;
    SourceTable = "FSN Global Table Temporary";
    SourceTableTemporary = true;

    layout
    {
        area(content)
        {
            group(General)
            {
                field("No. Ruta"; Int_2)
                {
                    Caption = 'No. Ruta', comment = 'ESP="No. Ruta"';
                }
                field("Moto ID"; Text_1)
                {
                    Caption = 'Moto ID', comment = 'ESP="Moto ID"';
                }
                field(Liquidador; Code20_3)
                {
                    Caption = 'Liquidador', comment = 'ESP="Liquidador"';
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(Liquidar)
            {
                Promoted = true;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Resultt: Text;
                begin
                    if (Text_1 <> '') and (Int_2 <> 0) THEN BEGIN
                        RequestID := 'RUNPAGEDAF';
                        XMLRequest := Text_1;
                        XMLResponse := FORMAT(Int_2);
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                        IF MsgResult <> '' THEN
                            MESSAGE('ERROR %1', MsgResult);
                    END ELSE BEGIN
                        MESSAGE('ERROR', TEXT000);
                    END;
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        INIT;
        Code20_3 := USERID;
        INSERT;
    end;

    var
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        TEXT000: Label 'No Ruta o Moto ID no pueden ser vacio';



}

