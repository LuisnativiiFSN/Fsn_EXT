pageextension 50138 "FSN Purchase Return Order" extends "Purchase Return Order"
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
    }
}