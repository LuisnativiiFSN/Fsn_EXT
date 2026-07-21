pageextension 50139 "FSN Purchase Credit Memo" extends "Purchase Credit Memo"
{
    layout
    {
        addafter(Status)
        {
            field("DTE AuthNumber"; Rec."DTE AuthNumber")
            {
                ApplicationArea = All;
            }
            field("DTE Invoice"; Rec."DTE Invoice")
            {
                ApplicationArea = All;
                trigger OnLookup(var Text: Text): Boolean
                var
                    ExtPurch: Codeunit "FSN External Purch. Manager";
                begin
                    if ExtPurch.OnLookupDte(Rec) then begin
                        Rec.Modify(true);
                        CurrPage.Update(true);
                    end;
                end;

                trigger OnValidate()
                var
                    ExtPurch: Codeunit "FSN External Purch. Manager";
                begin
                    if ExtPurch.OnValidateDte(Rec) then begin
                        Rec.Modify(true);
                        CurrPage.Update(true);
                    end;
                end;
            }
            field("Signature Validation"; Rec."Signature Validation")
            {
                ApplicationArea = All;
            }
        }
        addafter(PurchLines)
        {
            group(Withholding)
            {
                Caption = 'Detail Withhold';
                field("FSN Withholding Tax Amount"; Rec."FSN Withholding Tax Amount")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }

        }
    }
    var
        extPurch: Codeunit "FSN External Purch. Manager";

    trigger OnOpenPage()
    var
    begin
        //extPurch.CalcWithHold(Rec);
    end;

    trigger OnAfterGetRecord()
    begin
        //extPurch.CalcWithHold(Rec);
    end;


}