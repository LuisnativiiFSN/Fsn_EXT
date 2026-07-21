tableextension 50016 "FSN PurchReceiptHeaderExt" extends "Purch. Rcpt. Header"
{
    fields
    {
        field(50000; "FSN Vendor Invoice No."; Code[35])
        {
            DataClassification = ToBeClassified;

        }

        field(201; "SubTotal"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(202; "Tax"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(203; "Total"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(70000; "Invoiced"; Boolean)
        {
            Caption = 'Facturado';
            DataClassification = ToBeClassified;
        }

        field(80000; "FSN last message"; Text[2048])
        {
            Caption = 'Last message';
            DataClassification = ToBeClassified;
        }
        field(50100; "FSN VAT Difference"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'VAT Difference';
            Editable = false;
        }
    }
}