package com.shubus.backend.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.shubus.backend.dto.TransportProfileResponse;
import com.shubus.backend.model.Student;
import com.shubus.backend.model.StudentTransportProfile;
import com.shubus.backend.repository.StudentRepository;
import com.shubus.backend.repository.StudentTransportProfileRepository;

@RestController
@RequestMapping("/api/students")
public class TransportProfileController {

    private final StudentRepository studentRepository;
    private final StudentTransportProfileRepository profileRepository;

    public TransportProfileController(
            StudentRepository studentRepository,
            StudentTransportProfileRepository profileRepository) {

        this.studentRepository = studentRepository;
        this.profileRepository = profileRepository;
    }

    @GetMapping("/{regNo}/transport-profile")
    public TransportProfileResponse getTransportProfile(
            @PathVariable String regNo) {

        Student student = studentRepository.findByRegNo(regNo == null ? "" : regNo.trim())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Student not found"
                ));

        if (!Boolean.TRUE.equals(student.getActive())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN, "Student account is inactive");
        }

        StudentTransportProfile profile =
                profileRepository.findByStudentId(student.getId())
                        .orElseThrow(() -> new ResponseStatusException(
                                HttpStatus.NOT_FOUND,
                                "Transport profile not found"
                        ));

        return new TransportProfileResponse(
                student.getRegNo(),
                student.getName(),
                profile.getMorningRouteNumber(),
                profile.getMorningRouteName(),
                profile.getAcType()
        );
    }
}