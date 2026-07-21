table 50014 "FSN IntegrationMember"
{

    fields
    {
        field(10; Card; Text[100])
        {
            Caption = 'Card';
        }
        field(20; "Club Code"; Code[10])
        {
            Caption = 'Member Club Code';
            TableRelation = "LSC Member Club".Code;
        }
        field(30; "Scheme Code"; Code[10])
        {
            Caption = 'Member Scheme Code';
            TableRelation = "LSC Member Scheme".Code;
        }
        field(40; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer."No.";

            trigger OnValidate()
            var
                Customer_l: Record Customer;
            begin
                IF "Customer No." = '' THEN
                    "Customer Name" := ''
                ELSE
                    IF Customer_l.GET("Customer No.") THEN
                        "Customer Name" := Customer_l.Name;
            end;
        }
        field(45; "Customer Name"; Text[50])
        {
            Caption = 'Customer Name';
            Editable = false;
        }
        field(50; Status; Option)
        {
            Caption = 'Status';
            Editable = false;
            OptionCaption = 'Pending,Processed,Error';
            OptionMembers = Pending,Processed,Error;
        }
        field(60; "POS Terminal No."; Code[10])
        {
            Caption = 'POS Terminal No.';
            TableRelation = "LSC POS Terminal"."No.";
        }
        field(70; "Store No."; Code[10])
        {
            Caption = 'Store No.';
            TableRelation = "LSC Store"."No.";
        }
        field(80; Beneficiary; Text[100])
        {
            Caption = 'Beneficiary';
        }
        field(90; "Action"; Option)
        {
            Caption = 'Action';
            OptionCaption = 'Create,Renovate,VerifyReferences';
            OptionMembers = Create,Renovate,VerifyReferences;
        }
        field(100; StaffID; Code[20])
        {
            Caption = 'StaffID';
        }
        field(110; "Process Message"; Text[100])
        {
            Caption = 'Process Message';
            Editable = false;
        }
        field(120; "Date Processed"; Date)
        {
            Caption = 'Date Processed';
            Editable = false;
        }
        field(130; "Time Processed"; Time)
        {
            Caption = 'Time Processed';
            Editable = false;
        }
        field(140; "User Process"; Code[20])
        {
            Caption = 'User Process';
            Editable = false;
        }
        field(150; "Date Create Card"; Date)
        {
            Caption = 'Date Create Card';
            Editable = false;
        }
        field(160; "Counter Process"; Integer)
        {
            Caption = 'Counter Process';
            Editable = false;

            trigger OnValidate()
            begin
                "Counter Process" := xRec."Counter Process"
            end;
        }
        field(170; "Receipt No."; Code[20])
        {
            Editable = false;
        }
    }

    keys
    {
        key(Key1; Card)
        {
            Clustered = true;
        }
        key(Key2; Status)
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        IF Status = Status::Processed THEN
            ERROR(gText001);
    end;

    var
        gText001: Label 'Record is procecced';
}

