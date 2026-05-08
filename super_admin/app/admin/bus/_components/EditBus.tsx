"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { yupResolver } from "@hookform/resolvers/yup";
import { MdOutlineEdit } from "react-icons/md";
import type { BusProps } from "../BusProps";
import { BUS_STATUS_OPTIONS } from "../mapApiBus";
import { useUpdateBus } from "../_hooks/useUpdateBus";
import { editBusSchema, type EditBusFormData } from "./editBusSchema";

export const EDIT_BUS_MODAL_ID = "edit-bus-modal";

type EditBusProps = {
  bus: BusProps;
  modalId?: string;
  onCloseModal?: () => void;
  onBusUpdated?: () => void | Promise<void>;
};

const defaultValues: EditBusFormData = {
  bus_code: "",
  plate_number: "",
  maximum_capacity: 0,
  status: "active",
};

type BusStatusOption = (typeof BUS_STATUS_OPTIONS)[number];

export default function EditBusModal({
  bus,
  modalId,
  onCloseModal,
  onBusUpdated,
}: EditBusProps) {
  const id = modalId ?? `${EDIT_BUS_MODAL_ID}-${bus.id}`;
  const [submitError, setSubmitError] = useState<string | null>(null);
  const { updateBus, error: updateBusError } = useUpdateBus();
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<EditBusFormData>({
    resolver: yupResolver(editBusSchema),
    defaultValues,
  });

  useEffect(() => {
    if (bus) {
      const status = BUS_STATUS_OPTIONS.includes(bus.bus_status as BusStatusOption)
        ? (bus.bus_status as BusStatusOption)
        : "active";
      reset({
        bus_code: bus.bus_number,
        plate_number: bus.plate_number,
        maximum_capacity: bus.capacity,
        status,
      });
    } else {
      reset(defaultValues);
    }
  }, [bus, reset]);

  async function onSubmit(data: EditBusFormData) {
    if (!bus) return;
    try {
      setSubmitError(null);
      const response = await updateBus(bus.id, {
        bus_number: data.bus_code,
        plate_number: data.plate_number,
        capacity: data.maximum_capacity,
        status: data.status,
      });

      if (!response) {
        setSubmitError(updateBusError ?? "Failed to update bus");
        return;
      }

      await onBusUpdated?.();
      (document.getElementById(id) as HTMLDialogElement)?.close();
      onCloseModal?.();
    } catch {
      setSubmitError("Failed to update bus");
    }
  }

  function openModal() {
    setSubmitError(null);
    (document.getElementById(id) as HTMLDialogElement)?.showModal();
  }

  useEffect(() => {
    const el = document.getElementById(id) as HTMLDialogElement | null;
    if (!el) return;
    const onClose = () => onCloseModal?.();
    el.addEventListener("close", onClose);
    return () => el.removeEventListener("close", onClose);
  }, [id, onCloseModal]);

  return (
    <>
      <button
        type="button"
        className="btn btn-sm "
        onClick={openModal}
      >
        <MdOutlineEdit className="w-5 h-5" />
        Edit
      </button>
      <dialog id={id} className="modal">
      <div className="modal-box flex flex-col max-h-[90vh] p-0">
        <h3 className="font-bold text-lg p-4 pb-0">Edit bus</h3>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col flex-1 min-h-0">
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            <div className="form-control">
              <label className="label">
                <span className="label-text">Bus code</span>
              </label>
              <input
                type="text"
                placeholder="e.g. 01-AB"
                className={`input input-bordered w-full ${errors.bus_code ? "input-error" : ""}`}
                {...register("bus_code")}
              />
              {errors.bus_code && (
                <p className="text-error text-sm mt-1">{errors.bus_code.message}</p>
              )}
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Plate number</span>
              </label>
              <input
                type="text"
                placeholder="e.g. ABC 1234"
                className={`input input-bordered w-full ${errors.plate_number ? "input-error" : ""}`}
                {...register("plate_number")}
              />
              {errors.plate_number && (
                <p className="text-error text-sm mt-1">{errors.plate_number.message}</p>
              )}
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Maximum capacity</span>
              </label>
              <input
                type="number"
                min={1}
                max={999}
                placeholder="e.g. 45"
                className={`input input-bordered w-full ${errors.maximum_capacity ? "input-error" : ""}`}
                {...register("maximum_capacity", { valueAsNumber: true })}
              />
              {errors.maximum_capacity && (
                <p className="text-error text-sm mt-1">{errors.maximum_capacity.message}</p>
              )}
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Status</span>
              </label>
              <select
                className={`select select-bordered w-full ${errors.status ? "select-error" : ""}`}
                {...register("status")}
              >
                {BUS_STATUS_OPTIONS.map((status) => (
                  <option key={status} value={status}>
                    {status}
                  </option>
                ))}
              </select>
              {errors.status && (
                <p className="text-error text-sm mt-1">{errors.status.message}</p>
              )}
            </div>
          </div>
          <div className="modal-action sticky bottom-0 bg-base-100 border-t border-base-content/5 p-4 mt-0 shrink-0">
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => {
                (document.getElementById(id) as HTMLDialogElement)?.close();
                onCloseModal?.();
              }}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn bg-[#008DF7] hover:bg-[#008DF7]/80 text-white"
              disabled={isSubmitting}
            >
              {isSubmitting ? "Saving…" : "Save"}
            </button>
          </div>
          {submitError || updateBusError ? (
            <p className="text-error text-sm px-4 pb-4">{submitError ?? updateBusError}</p>
          ) : null}
        </form>
      </div>
      <form method="dialog" className="modal-backdrop">
        <button type="submit">close</button>
      </form>
    </dialog>
    </>
  );
}
