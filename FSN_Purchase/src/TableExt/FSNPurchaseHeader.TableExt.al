tableextension 50105 "FSN Purchase Header" extends "Purchase Header"
{
    fields
    {
        field(60000; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';

            DataClassification = ToBeClassified;
        }
        field(60001; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';

            DataClassification = ToBeClassified;
            trigger OnValidate()
            var
                VendorInvNumber: Integer;
                invoiceList: List of [Text];
                invoice: Text;
                util: Codeunit "FSN External Purch. Manager";
            begin
                /*
                if StrLen("DTE Invoice") = 31 then begin
                    invoice := "DTE Invoice";
                    invoiceList := invoice.Split('-');
                    Validate("Vendor Invoice Number", util.removeLeftZero(invoiceList.Get(invoiceList.Count)));
                    if invoice.Contains('DTE') then begin
                        Validate("Vendor Invoice Serie", invoiceList.Get(1) + invoiceList.Get(2));
                    end else
                        Validate("Vendor Invoice Serie", invoiceList.Get(1));
                    "Unique Document No." := invoice;
                    "Vendor Invoice No." := "Vendor Invoice Serie" + '-' + "Vendor Invoice Number";
                end else begin
                    Error('DTE no valido debe contener 31 caracteres incluyendo guiones: Ej DTE-03-M0010000-000000000000000');
                end;
                */

            end;
        }
        field(60002; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;
        }
        field(60010; "Associated Credit Memo"; Boolean)
        {
            Caption = 'Associated Credit Memo';
            DataClassification = ToBeClassified;
        }
        field(60011; "No. Credit Memo Associated"; Text[60])
        {
            Caption = 'No. Credit Memo Associated';
            DataClassification = ToBeClassified;

        }
        field(50100; "FSN VAT Difference"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'VAT Difference';
            Editable = false;
        }
        field(50101; "FSN Withholding Tax Amount"; Decimal)
        {
            DataClassification = ToBeClassified;
            AutoFormatType = 1;
            Caption = 'FSN Withholding Tax Amount';

        }
        field(60020; "Withhold DTE AuthNumber"; Code[36])
        {
            Caption = 'Withhold DTE AuthNumber';

            DataClassification = ToBeClassified;
        }
        field(60021; "Withhold DTE Invoice"; Code[31])
        {
            Caption = 'Withhold DTE Invoice';

            DataClassification = ToBeClassified;

        }
        field(60022; "Withhold Sign. Validation"; Text[50])
        {
            Caption = 'Withhold Sign. Validation';

            DataClassification = ToBeClassified;
        }
        field(60023; "SubTotal"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60024; "Tax"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60025; "Total"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60050; "FSN Alternative Order"; Integer)
        {
            CalcFormula = COUNT("Purchase Header" WHERE("Your Reference" = FIELD("No.")));
            Caption = 'Alternative Order';
            Editable = false;
            FieldClass = FlowField;
        }
        field(60051; "FSN Shared with EBS"; Boolean)
        {
            Caption = 'Shared with EBS';
            DataClassification = ToBeClassified;

        }
        field(60052; "FSN Outstanding Lines"; Integer)
        {
            Caption = 'Outstanding Lines';
            DataClassification = ToBeClassified;

        }
    }
}