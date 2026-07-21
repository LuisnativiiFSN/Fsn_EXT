pageextension 50032 "FSN Retail TO. tb. Picked Sub" extends "LSC Retail TO. tb. Picked Sub."
{
    layout
    {
        addbefore("Item No.")
        {
            field("FSN Barcode No."; Rec."FSN Barcode No.")
            {
                trigger OnValidate()
                var
                    Barcodes2: Record "LSC Barcodes";
                    Item2: Record Item;
                begin
                    if Barcodes2.Get(Rec."FSN Barcode No.") then begin
                        Rec.Validate("Item No.", Barcodes2."Item No.");
                        Rec.Validate("Unit of Measure Code", Barcodes2."Unit of Measure Code");
                        Rec."FSN Barcode No." := Barcodes2."Barcode No.";
                        if Item2.Get(Rec."Item No.") then
                            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";
                    end;
                    ValStatusScann;
                end;
            }
        }

        addbefore(Quantity)
        {
            field(Status; StatusScann)
            {
                StyleExpr = StyleStatusText;
                trigger OnValidate()
                var
                begin

                end;
            }
        }
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
    }

    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        ValStatusScann;
    end;

    trigger OnAfterGetRecord()
    begin
        ValStatusScann;
    end;

    var
        myInt: Integer;
        StatusScann: Text;
        StyleStatusText: Text;
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;


    procedure ValStatusScann()
    var
        myInt: Integer;
    begin
        if not Rec."FSN Checked" then
            StatusScann := 'Not Scanned'
        else
            StatusScann := 'Scanning';

        ProStyleStutus(StatusScann);
    end;

    procedure ProStyleStutus(TextStatus: Text)
    var
        myInt: Integer;
    begin
        if TextStatus = 'Scanning' then
            StyleStatusText := Format(StyleStatus::Favorable)
        else
            StyleStatusText := Format(StyleStatus::Unfavorable);
    end;
}