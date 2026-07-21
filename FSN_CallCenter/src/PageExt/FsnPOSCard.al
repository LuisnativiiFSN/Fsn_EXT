pageextension 50084 "Fsn Pos Carde ext" extends "LSC POS Card Entries"
{
    layout
    {
        addafter(Control1)
        {
            field(Amount; Amount)
            {
            }
        }// Add changes to page layout here
    }


    actions
    {
        addafter("Request Log")
        {
            group(Anular)
            {
                action("Anular-Voucher")
                {
                    Caption = 'Anular-Voucher';

                    trigger OnAction()
                    var
                        _EntryNo: Integer;
                        _Date: Date;
                        _AmountDecimal: Decimal;
                        _Remaining: Decimal;
                    begin
                        RequestID := 'NULLPOSCARDENTRY';
                        XMLRequest := Rec."Receipt No.";
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    end;
                }
            }
        }
    }

    var
        myInt: Integer;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
}