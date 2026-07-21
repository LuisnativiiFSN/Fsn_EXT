tableextension 50119 "Purchase LineExt" extends "Purchase Line"
{
    fields
    {
        field(60002; "FSN Direct Unit Cost"; Decimal)
        {
            Caption = 'FSN Direct Unit Cost';
            DataClassification = ToBeClassified;
        }
        field(60003; Barcode; Code[20])
        {
            Caption = 'Barcode';

            trigger OnValidate()
            var
                Item_L: Record Item;
                Barcodes: Record "LSC Barcodes";
                BarcodeMgmt: Codeunit "LSC Barcode Management";
                Amount: Decimal;
                Qty: Decimal;
            begin
                if Barcode = '' then
                    exit;

                if BarcodeMgmt.FindBarcodeDetails(Barcode, Item_L, Barcodes, Amount, Qty) then begin
                    Type := Type::Item;
                    Validate("No.", Barcodes."Item No.");
                    Barcode := Barcodes."Barcode No.";
                    "Variant Code" := Barcodes."Variant Code";
                    if Barcodes."Unit of Measure Code" <> '' then
                        Validate("Unit of Measure Code", Barcodes."Unit of Measure Code");
                end;
            end;
        }
    }

    var
        myInt: Integer;
}