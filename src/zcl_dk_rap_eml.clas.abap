CLASS zcl_dk_rap_eml DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_dk_rap_eml IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
*    read operation
*    READ ENTITIES OF zi_dk_rap_travel
*    ENTITY Travel
*    FROM  VALUE #( ( TravelUuid = '4E29A72025FE1EDEB4B1532FBB0E6CE2' ) )
*    RESULT DATA(le_travels).

* read limited fields
*    READ ENTITIES OF zi_dk_rap_travel
*    ENTITY Travel
*        FIELDS ( AgencyId CustomerId )
*    WITH  VALUE #( ( TravelUuid = '4E29A72025FE1EDEB4B1532FBB0E6CE2' ) )
*    RESULT DATA(le_travels).

*  read all the fields
*    READ ENTITIES OF zi_dk_rap_travel
*    ENTITY Travel
*    ALL FIELDS WITH
*    VALUE #( ( TravelUuid = '11111111111111111111111111111111' ) )
*    RESULT DATA(le_travels)
*    FAILED DATA(lt_failed)
*    REPORTED DATA(lt_reported).
*
*    out->write( le_travels ).
*    out->write( lt_failed ). " complex structures not supported by the console output
*
*    out->write( lt_reported ). " complex structures not supported by the console output

*  read by association
*    READ ENTITIES OF zi_dk_rap_travel
*    ENTITY Travel BY \_Booking " read by assocaiations
*    ALL FIELDS WITH VALUE #( ( TravelUuid = '4E29A72025FE1EDEB4B1532FBB0E6CE2' ) )
*    RESULT DATA(le_booking).
*
*    out->write( le_booking ).

* read booking directly
*    READ ENTITIES OF zi_dk_rap_travel
*    ENTITY Booking
*    ALL FIELDS WITH VALUE #( ( BookingUuid = '4E29A72025FE1EDEB4B15573CEC54CF5' ) )
*    RESULT DATA(le_booking).
*
*    out->write( le_booking ).

**********************************************************************
** modify entity
*    MODIFY ENTITIES OF zi_dk_rap_travel
*    ENTITY Travel
*    UPDATE
*        SET FIELDS WITH VALUE
*#( ( TravelUuid = '4E29A72025FE1EDEB4B1532FBB0E6CE2' Description = 'Test description' ) )
*            FAILED DATA(lt_failed)
*            REPORTED DATA(lt_reported).
*
***********************************************************************
**  commit entites
*    COMMIT ENTITIES
*    RESPONSE OF zi_dk_rap_travel
*    FAILED DATA(lt_fail_commit)
*    REPORTED DATA(lt_rep_commit).
*
*    out->write( 'update done' ).

**********************************************************************
* create instance

*    MODIFY ENTITIES OF zi_dk_rap_travel
*    ENTITY Travel
*        CREATE
*            SET FIELDS WITH VALUE #(
*                (   %cid        = 'MyContentID_1'
*                    AgencyId    = '70012'
*                    CustomerId  = '14'
*                    BeginDate   = cl_abap_context_info=>get_system_date( )
*                    EndDate     = cl_abap_context_info=>get_system_date( ) + 10
*                    Description = 'I like to travel new instance'
*                    )
*    )
*    MAPPED DATA(lt_mapped)
*    FAILED DATA(lt_failed)
*    REPORTED DATA(lt_reported).
*
*    out->write( lt_mapped-travel ).
*
*    "commit work.
*    COMMIT ENTITIES
*    RESPONSE OF zi_dk_rap_travel
*    FAILED DATA(lt_fail_commit)
*    REPORTED DATA(lt_rep_commit).
*
*    out->write( 'Crate done ' ).

**********************************************************************
* delete instance
    MODIFY ENTITIES OF zi_dk_rap_travel
    ENTITY Travel
    DELETE FROM
    VALUE #(
    ( TravelUuid = '4E29A72025FE1EDEB4B24E950D154F44' ) " newly created in last step
    )
    FAILED DATA(lt_failed)
    REPORTED DATA(lt_reported).

    COMMIT ENTITIES RESPONSE OF zi_dk_rap_travel
    FAILED DATA(lt_fail_commit)
    REPORTED DATA(lt_rep_commit).

    out->write( 'Delete Done' ).




  ENDMETHOD.
ENDCLASS.
