import type { CreateMember } from "../types/CreateMember";
import type { Member } from "../types/Member";

export const getMembers = async (): Promise<Member[]> => {
    const response = await fetch("http://localhost:8080/members");

    return await response.json();
};

export const deleteMember = async (id: number) => {
     await fetch(`http://localhost:8080/members/${id}`, {
        method: `DELETE`});
    };

export const addMember = async (createMember: CreateMember): Promise<Member[]> => {
    await fetch(`http://localhost:8080/members`, {
        method: 'POST',
        headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(createMember)
});
    return getMembers();
};

export const getMemberById = async (id: number): Promise<Member> => {
    const response = await fetch(`http://localhost:8080/members/${id}`);
    return response.json();
}

export const updateMember = async (member: Member): Promise<Member[]> => {
    await fetch(`http://localhost:8080/members/${member.id}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(member)
    });
    const response = await fetch(`http://localhost:8080/members`);
    return response.json();
};
