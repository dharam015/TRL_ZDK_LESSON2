CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculateBookingID FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculateBookingID.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculateTotalPrice.

ENDCLASS.

CLASS lhc_Booking IMPLEMENTATION.

  METHOD calculateBookingID.
    DATA: max_bookingid TYPE /dmo/booking_id.
    DATA: update TYPE TABLE FOR UPDATE zi_dk_rap_travel\\Booking.

    "read all travel for the requested bookings.
    " if multiple bookings of the same
    " read all travel for the requested bookings.
    " if multiple bookings of the same travel are requested, the travel is returned only once.

    READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE ENTITY Booking BY \_Travel
    FIELDS (  TravelUuid ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).
    " process all affected travels . read respective bookings, determine the max-id and upate the booking without id.
    LOOP AT travels INTO DATA(travel).
      READ ENTITIES OF zi_dk_rap_travel IN LOCAL MODE ENTITY travel BY \_Booking
      FIELDS ( BookingId ) WITH VALUE #( ( %tky = travel-%tky ) )
      RESULT DATA(bookings).
      " this will give all the bookings under travel
      "find the max used booking id in all the booking
      max_bookingid = '000'.

      LOOP  AT bookings INTO DATA(booking).
        IF booking-BookingId > max_bookingid.
          max_bookingid = booking-BookingId.
        ENDIF.
      ENDLOOP.

      "provide a booking id for all the booking that have no id.
      LOOP AT bookings INTO booking WHERE BookingId IS INITIAL.
        max_bookingid += 10. " increase booking id by 10
        APPEND VALUE #( %tky = booking-%tky BookingId = max_bookingid ) TO update.
      ENDLOOP.
    ENDLOOP.

    " update the booking id in all the relvant bookings.
    MODIFY ENTITIES OF zi_dk_rap_travel IN LOCAL MODE ENTITY Booking
    UPDATE FIELDS ( BookingId ) WITH update REPORTED DATA(update_reported) FAILED DATA(failed).

    reported = CORRESPONDING #( DEEP update_reported ).

  ENDMETHOD.

  METHOD calculateTotalPrice.
    "read all travels from the request booking.
    READ ENTITIES OF zi_dk_Rap_Travel IN LOCAL MODE ENTITY Booking BY \_Travel
    FIELDS ( TravelUuid ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels) FAILED DATA(read_failed).

    " trigger calculation of total price
    MODIFY ENTITIES OF zi_dk_Rap_travel IN  LOCAL MODE ENTITY Travel
    EXECUTE reCalculateTotalPrice FROM CORRESPONDING #( travels )
    REPORTED DATA(executed_Reported).
    reported = CORRESPONDING #( DEEP executed_reported ).
  ENDMETHOD.

ENDCLASS.
