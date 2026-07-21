pageextension 50055 "FSN RetailTransferOrderExt" extends "LSC Retail TO. Subp." //"Retail Transfer Order Subf."
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
                        Rec.Validate("Unit of Measure", Barcodes2."Unit of Measure Code");
                        if Item2.Get(Rec."Item No.") then
                            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";
                    end;
                    ValStatusScann;
                end;
            }
        }
        addbefore(Description)
        {
            field("FSN Attrib 1 Code"; Rec."FSN Attrib 1 Code") { }
        }

        addbefore(Description)
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
        modify(Quantity)
        {
            Editable = EditQuantitys;
        }
        modify(QtyToShip)
        {
            Editable = EditQuantitys;
        }
    }
    actions
    {
    }
    trigger OnModifyRecord(): boolean
    var
        Item2: Record Item;
    begin
        if (Rec."Item No." <> '') and Item2.Get(Rec."Item No.") then
            Rec."FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

    end;

    trigger OnAfterGetRecord()
    begin
        ValStatusScann;
        if not FirstRead then begin
            if TransferHeader.Get(Rec."Document No.") then begin
                EditQuantitys := TransferHeader."LSC Retail Status" = 0;
            end;
            FirstRead := true;
        end;
    end;

    trigger OnOpenPage()
    begin
        FirstRead := false;
        ValStatusScann;
    end;

    var
        TransferHeader: Record "Transfer Header";
        FirstRead: Boolean;
        EditQuantitys: Boolean;
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

